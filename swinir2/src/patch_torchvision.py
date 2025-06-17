# This file patches the torchvision.transforms.functional_tensor module
# to provide compatibility with newer versions of torchvision

import sys
import importlib
from functools import wraps

# Try to import from the new location first
try:
    from torchvision.transforms.functional import rgb_to_grayscale
except ImportError:
    # If that fails, try the old location
    try:
        from torchvision.transforms.functional_tensor import rgb_to_grayscale
    except ImportError:
        # If both fail, provide a simple implementation
        import torch
        def rgb_to_grayscale(img):
            """
            Convert RGB image to grayscale.
            Args:
                img (Tensor): RGB Image to be converted to grayscale.
            Returns:
                Tensor: Grayscale image.
            """
            if img.shape[0] != 3:
                raise TypeError('Input image tensor should have 3 channels')
            
            # Use the standard RGB to grayscale conversion formula
            r, g, b = img.unbind(0)
            gray = 0.2989 * r + 0.5870 * g + 0.1140 * b
            return gray.unsqueeze(0)

# Create a fake module to provide the missing functions
class FakeFunctionalTensor:
    @staticmethod
    def rgb_to_grayscale(img):
        return rgb_to_grayscale(img)

# Add the fake module to sys.modules
sys.modules['torchvision.transforms.functional_tensor'] = FakeFunctionalTensor