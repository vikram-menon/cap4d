from argparse import ArgumentParser
from pathlib import Path

import numpy as np
import torch
from omegaconf import OmegaConf
from plyfile import PlyData, PlyElement

from gaussianavatars.gaussian_renderer.gsplat_renderer import export_gaussians
from gaussianavatars.scene.cap4d_gaussian_model import CAP4DGaussianModel
from gaussianavatars.scene.scene import Scene
from gaussianavatars.utils.general_utils import safe_state
from gaussianavatars.utils.system_utils import searchForMaxIteration


def write_standard_3dgs_ply(path, gaussians_dict):
    xyz = gaussians_dict["xyz"]
    normals = gaussians_dict["normals"]
    f_dc = gaussians_dict["f_dc"]
    f_rest = gaussians_dict["f_rest"]
    opacities = gaussians_dict["opacities"]
    scales = gaussians_dict["scale"]
    rotations = gaussians_dict["rotation"]

    names = ["x", "y", "z", "nx", "ny", "nz"]
    names.extend([f"f_dc_{i}" for i in range(f_dc.shape[1])])
    names.extend([f"f_rest_{i}" for i in range(f_rest.shape[1])])
    names.append("opacity")
    names.extend([f"scale_{i}" for i in range(scales.shape[1])])
    names.extend([f"rot_{i}" for i in range(rotations.shape[1])])

    attributes = np.concatenate(
        [xyz, normals, f_dc, f_rest, opacities, scales, rotations],
        axis=1,
    )
    dtype_full = [(name, "f4") for name in names]
    elements = np.empty(attributes.shape[0], dtype=dtype_full)
    elements[:] = list(map(tuple, attributes))

    path.parent.mkdir(parents=True, exist_ok=True)
    PlyData([PlyElement.describe(elements, "vertex")]).write(path)


def main(args):
    model_path = Path(args.model_path)
    output_ply = Path(args.output_ply)

    avatar_config = OmegaConf.load(model_path / "config_dump.yaml")
    gaussians = CAP4DGaussianModel(avatar_config["model_params"])
    gaussians.eval()

    # Scene loading initializes FLAME sequence data required before restore().
    Scene(
        source_paths=args.source_paths,
        target_paths=None,
        model_path=model_path,
        gaussians=gaussians,
        shuffle=False,
    )

    loaded_iter, chkpt_path = searchForMaxIteration(model_path)
    assert loaded_iter is not None, f"No valid checkpoint found in {model_path}"
    print(f"Loading trained model at iteration {loaded_iter}")
    model_weights, _ = torch.load(chkpt_path, weights_only=False)
    gaussians.restore(model_weights)
    gaussians.eval()

    n_timesteps = gaussians.flame_param["expr"].shape[0]
    timestep = args.timestep
    if timestep < 0:
        timestep = n_timesteps + timestep

    if timestep < 0 or timestep >= n_timesteps:
        raise ValueError(f"Invalid timestep {args.timestep}; expected in [0, {n_timesteps - 1}] or negative index.")

    gaussians.select_mesh_by_timestep(timestep)
    gaussians_dict = export_gaussians(gaussians)
    write_standard_3dgs_ply(output_ply, gaussians_dict)

    print(f"Exported static 3DGS ply to: {output_ply}")
    print(f"Timestep used: {timestep}")


if __name__ == "__main__":
    parser = ArgumentParser(description="Export a static Unity-friendly 3DGS ply from a trained CAP4D avatar.")
    parser.add_argument(
        "--model_path",
        type=str,
        required=True,
        help="Path to trained avatar directory containing config_dump.yaml and checkpoints.",
    )
    parser.add_argument(
        "--source_paths",
        type=str,
        nargs="+",
        required=True,
        help="Source directories used for avatar training (reference_images and generated_images).",
    )
    parser.add_argument(
        "--output_ply",
        type=str,
        required=True,
        help="Path to output static 3DGS ply file.",
    )
    parser.add_argument(
        "--timestep",
        type=int,
        default=0,
        help="FLAME timestep to bake before exporting. Default: 0 (first frame). Supports negative indexing.",
    )
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    safe_state(args.quiet)

    with torch.no_grad():
        main(args)
