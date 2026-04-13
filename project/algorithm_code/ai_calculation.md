The dominant kernels are MaxPool2D.forward and MaxPool2D.backward accounting for 14% and 7.83% of total runtime  
respectively.

Dominant Kernel (~14% of run time): MaxPool2D.forward 

**Number of FLOPs:**  
Number of Spatial Positions(H,W) = 8 x 8 = 64  
Number of arithmetic operations per position = 4  
FLOPs per call = 4 x 64 = 256  
Number of calls = 380  
Total FLOPs = 256 x 380 = 97,280 FLOPs

**Memory Traffic:**  
x.shape size = (32,8,16,16)  
number of elements = 32 x 8 x 16 x 16 = 65,536  
total number of bytes over 380 calls = 4 x 65,536 x 380 = 99614720 bytes  

output written to memory size = (32,8,8,8)  
number of elements = 32 x 8 x 8 x 8 = 16,384  
total number of bytes over 380 calls = 4 x 16384 x 380 = 24903680 bytes  

mask written to memory size = (32, 8, 16, 16)  
number of elements = 65,536  
total number of bytes over 380 calls(1 byte per mask element) = 1 x 380 x 65538 = 24903680 bytes

total memory traffic over 380 calls = 149423600 bytes


**Arithmetic Intensity:**  
AI = 97,280 / 149423600 ~= 0.000651 FLOPs/byte

Secondary Dominant Kernel(~7.83% of run time): MaxPool2D.backward
AI = 131,328 / 1,179,648 ~= 0.111FLOPs/bye