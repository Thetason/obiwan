#!/usr/bin/env python3
"""
Build CREPE Keras model from source (vendor/crepe), export to TFLite and CoreML.

Usage:
  source obiwan/.venv311/bin/activate
  python obiwan/scripts/build_crepe_models.py --capacity small --out_dir obiwan/ios/Runner/Models

Requires:
  - tensorflow-macos (tested 2.12.0)
  - coremltools (tested 8.3.0)
"""
import argparse
import os
import sys
import pathlib
import coremltools as ct
import tensorflow as tf


def import_local_crepe():
    root = pathlib.Path(__file__).resolve().parents[2]  # go up to obiwan
    vendor = root / 'vendor' / 'crepe'
    sys.path.insert(0, str(vendor))
    import crepe  # noqa: F401
    return crepe


def build_keras(crepe_mod, capacity: str):
    model = crepe_mod.core.build_and_load_model(capacity)
    # Remove optimizer to simplify conversion
    model.compile()
    return model


def save_keras(model, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    h5 = os.path.join(out_dir, 'CREPE_keras.h5')
    model.save(h5, include_optimizer=False)
    print(f"Saved Keras model: {h5}")
    return h5


def convert_tflite(model, out_dir):
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite = converter.convert()
    tflite_path = os.path.join(out_dir, 'crepe_small_float16.tflite')
    with open(tflite_path, 'wb') as f:
        f.write(tflite)
    print(f"Saved TFLite model: {tflite_path}")
    return tflite_path


def convert_coreml_from_keras(model, out_dir):
    # Specify input shape explicitly to avoid flexible placeholder warnings
    mlmodel = ct.convert(
        model,
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.iOS15,
        compute_units=ct.ComputeUnit.ALL,
        inputs=[ct.TensorType(name="input", shape=(1, 1024))],
    )
    ml_path = os.path.join(out_dir, 'CREPE.mlmodel')
    mlmodel.save(ml_path)
    print(f"Saved CoreML model: {ml_path}")
    # compile
    os.system(f"xcrun coremlc compile {ml_path} {out_dir}")
    return os.path.join(out_dir, 'CREPE.mlmodelc')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--capacity', default='small', choices=['tiny','small','medium','large','full'])
    parser.add_argument('--out_dir', required=True)
    args = parser.parse_args()

    crepe_mod = import_local_crepe()
    model = build_keras(crepe_mod, args.capacity)
    save_keras(model, args.out_dir)
    # Try CoreML direct from Keras first (preferred)
    try:
        convert_coreml_from_keras(model, args.out_dir)
    except Exception as e:
        print(f"CoreML from Keras failed: {e}")
        # fallback via TFLite
        tflite_path = convert_tflite(model, args.out_dir)
        mlmodel = ct.convert(tflite_path, source='tensorflow', minimum_deployment_target=ct.target.iOS15)
        ml_path = os.path.join(args.out_dir, 'CREPE.mlmodel')
        mlmodel.save(ml_path)
        os.system(f"xcrun coremlc compile {ml_path} {args.out_dir}")


if __name__ == '__main__':
    main()
