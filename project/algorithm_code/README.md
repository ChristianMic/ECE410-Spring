# Convolutional neural network with manual backpropagation (pure NumPy)

A fully manual CNN implementation in NumPy. Every forward pass and backward pass is computed analytically, including the im2col convolution, max-pooling gradient via switch masks, GELU/ReLU activations, and dense layer gradients. No autograd, no deep learning framework.

## What is implemented

- `Conv2D`: 2D convolution using im2col, with full backward pass via col2im
- `MaxPool2D`: max pooling with tie-breaking and exact gradient routing
- `ReLU`: elementwise activation with subgradient backward
- `Flatten` / `Dense`: standard fully connected layer with gradient
- `SoftmaxCrossEntropy`: numerically stable loss with analytic gradient
- `CNN`: composable model builder from config dict
- `AdamOptimizer`: adaptive gradient optimizer applied to all parameter layers
- Configurable architecture depth and width
- Built-in synthetic dataset generator for zero-dependency testing
- MNIST CSV loader for real data

## Files

```
cnn_backprop/
  cnn.py       -- all layers, model, optimizer, training loop
  train.py     -- CLI entry point, data loading, plotting
```

## Dependencies

```
numpy
matplotlib   # optional, for training curves
```

```bash
pip install numpy matplotlib
```

## Quickstart

Run on the synthetic dataset with no downloads required:

```bash
python train.py --data synthetic --config small --epochs 5
```

Expected output:

```
Generating synthetic dataset ...
Train: (2000, 1, 16, 16)  Val: (400, 1, 16, 16)
Epoch   1 | loss 1.73 | val acc 0.90
Epoch   2 | loss 0.84 | val acc 0.98
...
```

The synthetic dataset places class-specific stripe patterns in 16x16 images. It is visually trivial but correct for verifying that convolution, pooling, and backprop are all functioning.

## Scaling the problem

### Dataset size

Increase `--n_train` to stress-test throughput:

```bash
python train.py --data synthetic --n_train 10000 --config medium --epochs 10
```

### Network depth and width

Two built-in configs:

| Config | Conv layers        | Dense layers | Approx params |
|--------|--------------------|--------------| --------------|
| small  | 8 filters, 3x3    | [64]         | ~15K          |
| medium | 16, 32 filters    | [128, 64]    | ~100K         |

### Real data (MNIST)

Download the MNIST CSV from Kaggle (digit-recognizer competition) and place it at `data/mnist_train.csv`:

```bash
python train.py --data mnist --config medium --epochs 10
```

With the medium config on full MNIST (42K training samples), you should reach roughly 96-97% validation accuracy within 10 epochs.

### Custom architecture

```python
from cnn import CNN, train
import numpy as np

config = {
    "input_shape": (1, 28, 28),
    "conv_layers": [
        (32, 3, 1),   # 32 filters, 3x3, padding=1 (same)
        (64, 3, 1),
    ],
    "pool_size": 2,
    "pool_stride": 2,
    "dense_layers": [256, 128],
    "n_classes": 10,
    "batch_size": 64,
    "n_epochs": 15,
    "lr": 5e-4,
    "weight_decay": 1e-4,
}

model = CNN(config)
# X_train: (N, C, H, W) float32, y_train: (N,) int32
history = train(model, X_train, y_train, X_val, y_val, config)
```

### Deeper networks

Add more conv blocks or increase filter counts to push computation higher. Each conv layer is O(N * C_out * C_in * k^2 * H_out * W_out) per batch, which scales strongly with filter count and spatial resolution.

## Python API usage

### Training from arrays

```python
from cnn import CNN, train
import numpy as np

# X shape: (N, channels, height, width)   values in [0, 1]
# y shape: (N,)                            integer class labels

config = {
    "input_shape": (1, 28, 28),
    "conv_layers": [(16, 3, 1)],
    "pool_size": 2, "pool_stride": 2,
    "dense_layers": [128],
    "n_classes": 10,
    "batch_size": 64,
    "n_epochs": 10,
    "lr": 1e-3,
    "weight_decay": 1e-4,
}

model = CNN(config)
history = train(model, X_train, y_train, X_val, y_val, config)
print(history["val_acc"])
```

### Inference

```python
# Single batch prediction
preds = model.predict(X_test)   # returns class indices

# Raw logits
logits = model.forward(X_test)
```

### Gradient checking

A finite-difference check on the first dense layer:

```python
from cnn import CNN, SoftmaxCrossEntropy
import numpy as np

config = {
    "input_shape": (1, 8, 8),
    "conv_layers": [(4, 3, 1)],
    "pool_size": 2, "pool_stride": 2,
    "dense_layers": [16],
    "n_classes": 4,
}
model = CNN(config)
loss_fn = model.loss_fn
rng = np.random.default_rng(0)
X = rng.uniform(0, 1, (4, 1, 8, 8)).astype(np.float64)
y = np.array([0, 1, 2, 3], dtype=np.int32)

logits = model.forward(X)
loss = loss_fn.forward(logits, y)
dloss = loss_fn.backward()
model.backward(dloss)

# Check one weight in the last dense layer
dense = [l for l in model.layers if hasattr(l, 'dW')][-1]
eps = 1e-5
for i in range(4):
    dense.W.flat[i] += eps
    l1 = loss_fn.forward(model.forward(X), y)
    dense.W.flat[i] -= 2 * eps
    l2 = loss_fn.forward(model.forward(X), y)
    dense.W.flat[i] += eps
    num = (l1 - l2) / (2 * eps)
    ana = dense.dW.flat[i]
    print(f"W[{i}]: numerical={num:.6f}  analytical={ana:.6f}")
```

## Computational notes

The im2col implementation loops over spatial positions in Python, which is the main bottleneck. For large images or many filters, training is slow compared to a vectorized or C-backed implementation. This is intentional -- the goal is clarity, not speed. Replacing the Python loops in `_im2col` and `_col2im` with `np.lib.stride_tricks` or Cython would give a significant speedup without changing the mathematical structure.

Approximate throughput on a modern CPU (float64):

| Config | Input size | Samples/sec |
|--------|------------|-------------|
| small  | 16x16      | ~500-1000   |
| small  | 28x28      | ~200-400    |
| medium | 28x28      | ~50-150     |
