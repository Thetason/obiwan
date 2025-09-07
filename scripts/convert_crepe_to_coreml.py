#!/usr/bin/env python3
"""
Convert CREPE Tiny/Lite TFLite model to CoreML (.mlmodel) and compile to .mlmodelc

Requirements (create a venv and install):
  pip install coremltools>=6.3 tensorflow==2.12.*

Input:
  - Path to CREPE TFLite model (e.g., crepe_tiny.tflite)

Usage:
  python scripts/convert_crepe_to_coreml.py \
      --tflite path/to/crepe_tiny.tflite \
      --out ios/Runner/Models/CREPE.mlmodelc

Notes:
  - This script assumes a 1-D Float32 input tensor (audio frame) and outputs f0/confidence tensors.
  - If the TFLite IO names differ, update the `inputs/outputs` mapping below.
"""
import argparse
import coremltools as ct
import json
import os
import subprocess


def convert(tflite_path: str, out_dir: str):
    assert os.path.isfile(tflite_path), f"TFLite not found: {tflite_path}"
    os.makedirs(out_dir, exist_ok=True)

    print(f"Loading TFLite model: {tflite_path}")
    mlmodel = ct.convert(
        tflite_path,
        source='tensorflow',
        compute_units=ct.ComputeUnit.ALL,
        minimum_deployment_target=ct.target.iOS15,
    )

    # Optional: rename outputs if needed
    # e.g., mlmodel = mlmodel.rename_feature_map({"Identity": "f0", "Identity_1": "confidence"})

    mlmodel_path = os.path.join(out_dir, 'CREPE.mlmodel')
    print(f"Saving CoreML model: {mlmodel_path}")
    mlmodel.save(mlmodel_path)

    # Compile to .mlmodelc
    compiled_dir = out_dir
    print(f"Compiling to .mlmodelc in: {compiled_dir}")
    subprocess.run(['xcrun', 'coremlc', 'compile', mlmodel_path, compiled_dir], check=True)
    print("Done. Place CREPE.mlmodelc under ios/Runner/Models and build the iOS app.")


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--tflite', required=True, help='Path to crepe_tiny.tflite')
    parser.add_argument('--out', required=True, help='Output directory (e.g., ios/Runner/Models)')
    args = parser.parse_args()
    convert(args.tflite, args.out)
