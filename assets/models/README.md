# 3D Models Directory

This directory should contain the following GLB model files:

1. **human_torso.glb** - Human torso model for posture visualization
2. **vocal_tract.glb** - Vocal tract anatomy model
3. **breathing_guide.glb** - Diaphragmatic breathing guide model

## Model Requirements

- Format: GLB (Binary glTF)
- Size: < 5MB per model recommended
- Animations: Include relevant animations in the model file

## Fallback Behavior

If models are not present, the app will generate basic placeholder geometry.

## Where to Get Models

1. **Free Sources:**
   - Sketchfab (https://sketchfab.com) - Search for CC licensed anatomical models
   - Google Poly (archived but still accessible)
   - Mixamo (for human models)

2. **Create Your Own:**
   - Blender (free, open source)
   - Export as GLB format

3. **Quick Solution:**
   - Use simple primitive shapes as placeholders
   - The app already has fallback code that creates basic cube geometry