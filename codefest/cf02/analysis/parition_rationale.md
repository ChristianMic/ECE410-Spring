The kernels that I will be accelerating with my co-processor chiplet are MaxPool2D.forward and MaxPool2D.backward.  
These two are the most dominant kernels within the system (~14% ~7% total runtime respectively) adding up to 21% of total  
run time. The roofline analysis shows that both kernels are memory bound and are underperforming when it comes to memory  
operations and their Arithmetic intensity could be improved. This is likely due to software overhead and memory demand,  
so I believe both kernels would benefit from acceleration targeting both kernels to seperate them from software overhead.  
The Chiplet would do most memory operations and computational operations within the chiplet. For the forward kernel, a comparator tree will  
allow all comparisons to be done on the chip itself, removing it from any overhead. The software will still handle all other kernels and 
light memory/computational operations.

To accomplish this a chiplet will need an interface greater than 1GB/s. A 2GB/s interface should suffice, but since the CPU has  
a peak bandwidth of 41.6GB/s it could become interface bound if the chiplet speeds everything up enough. Although I expect improvement indicating
AI, with the current memory demand I expect the accelerated chip to still be memory bound which can be seen in the roofline model.
