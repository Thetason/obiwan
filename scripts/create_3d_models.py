#!/usr/bin/env python3
"""
Create simple 3D models for the vocal trainer app
Requires: pip install trimesh numpy
"""

import trimesh
import numpy as np
import os

def create_human_torso():
    """Create a simplified human torso model"""
    # Create torso as a tapered cylinder
    torso = trimesh.creation.cylinder(radius=0.4, height=1.2)
    
    # Add shoulders as horizontal cylinder
    shoulders = trimesh.creation.cylinder(radius=0.15, height=1.0)
    shoulders.apply_transform(trimesh.transformations.rotation_matrix(np.pi/2, [0, 0, 1]))
    shoulders.apply_translation([0, 0, 0.5])
    
    # Add chest expansion indicator (sphere)
    chest = trimesh.creation.icosphere(subdivisions=2, radius=0.35)
    chest.apply_translation([0, 0.1, 0])
    
    # Combine meshes
    torso_model = trimesh.util.concatenate([torso, shoulders, chest])
    
    # Add simple vertex colors (skin tone)
    torso_model.visual.vertex_colors = [255, 220, 177, 255]
    
    return torso_model

def create_vocal_tract():
    """Create a simplified vocal tract model"""
    # Create throat as cylinder
    throat = trimesh.creation.cylinder(radius=0.1, height=0.4)
    
    # Create mouth cavity as scaled sphere
    mouth = trimesh.creation.icosphere(subdivisions=2, radius=0.15)
    mouth.apply_transform(trimesh.transformations.scale_matrix(1.5, origin=[0, 0, 0], direction=[1, 0, 0]))
    mouth.apply_translation([0, 0, 0.3])
    
    # Create tongue as ellipsoid
    tongue = trimesh.creation.icosphere(subdivisions=2, radius=0.08)
    tongue.apply_transform(trimesh.transformations.scale_matrix(2.0, origin=[0, 0, 0], direction=[1, 0, 0]))
    tongue.apply_translation([0, -0.05, 0.25])
    
    # Combine meshes
    vocal_model = trimesh.util.concatenate([throat, mouth, tongue])
    
    # Add colors
    throat.visual.vertex_colors = [255, 200, 200, 255]
    mouth.visual.vertex_colors = [255, 180, 180, 255]
    tongue.visual.vertex_colors = [255, 150, 150, 255]
    
    return vocal_model

def create_breathing_guide():
    """Create a diaphragm breathing visualization model"""
    # Create ribcage as torus
    ribcage = trimesh.creation.torus(major_radius=0.4, minor_radius=0.1)
    ribcage.apply_transform(trimesh.transformations.scale_matrix(1.0, origin=[0, 0, 0], direction=[0, 0, 1]))
    
    # Create diaphragm as disk
    diaphragm = trimesh.creation.cylinder(radius=0.35, height=0.05)
    diaphragm.apply_translation([0, 0, -0.2])
    
    # Create lungs as two spheres
    lung_left = trimesh.creation.icosphere(subdivisions=2, radius=0.2)
    lung_left.apply_translation([-0.15, 0, 0.1])
    
    lung_right = trimesh.creation.icosphere(subdivisions=2, radius=0.2)
    lung_right.apply_translation([0.15, 0, 0.1])
    
    # Combine meshes
    breathing_model = trimesh.util.concatenate([ribcage, diaphragm, lung_left, lung_right])
    
    # Add colors
    ribcage.visual.vertex_colors = [200, 200, 200, 255]
    diaphragm.visual.vertex_colors = [255, 150, 150, 255]
    lung_left.visual.vertex_colors = [255, 200, 200, 255]
    lung_right.visual.vertex_colors = [255, 200, 200, 255]
    
    return breathing_model

def export_to_glb(mesh, filename):
    """Export mesh to GLB format"""
    # Ensure the mesh has proper scene graph
    scene = trimesh.Scene(mesh)
    
    # Export as GLB
    glb_data = scene.export(file_type='glb')
    
    with open(filename, 'wb') as f:
        f.write(glb_data)
    
    print(f"Created: {filename}")

def main():
    # Create output directory if it doesn't exist
    os.makedirs('/Users/seoyeongbin/vocal_trainer_ai/assets/models', exist_ok=True)
    
    # Create and export models
    print("Creating 3D models...")
    
    # Human torso
    torso = create_human_torso()
    export_to_glb(torso, '/Users/seoyeongbin/vocal_trainer_ai/assets/models/human_torso.glb')
    
    # Vocal tract
    vocal = create_vocal_tract()
    export_to_glb(vocal, '/Users/seoyeongbin/vocal_trainer_ai/assets/models/vocal_tract.glb')
    
    # Breathing guide
    breathing = create_breathing_guide()
    export_to_glb(breathing, '/Users/seoyeongbin/vocal_trainer_ai/assets/models/breathing_guide.glb')
    
    print("\nAll models created successfully!")
    print("Models are simplified representations suitable for demonstration.")

if __name__ == "__main__":
    main()