a) I will be accelerating the kernels MaxPool2D.forward and MaxPool2D.backward. The roofline analysis  
shows that both kernels are memory bound, and could benefit from acceleration targeting memory operations.  

b) The software baseline will continue to handel all computational operations within the system.

c) The interface bandwidtch would need to be greater greater than 41.6GB/s, otherwise it will become
bottlenecked

d) The kernels are memory bound on my current hardware. The accelerated hardware I expect to still be memory bound,
it will loosen the bottleneck allowing a higher arithmetic intensity.

The kernels that I will be accelerating with my co-processor chiplet are MaxPool2D.forward and MaxPool2D.backward.
These are two most dominant kernels within the system, making them an obvious target for acceleration.
The roofline analysis shows that both of the kernels are memory bound and quite far left from the ridge point. Due 
to this, I believe both kernels could benefit from acceleration targeting memory operations. Since the chiplet will 
be accelerating only memory based operations, the software will still continue to handle all computational operations. 
I am certain the software will be able to handle this as the current kernels are far to the left of the ridge point
indicating that the kernels are not bottlenecked by computational operations.

To accomplish this, the chiplet will need an interface with a bandwidth greater than my hardware's 41.6GB/s rate. If this is
not followed, the system will become interface bound. The interface that fits this requirement is the UCIe which has a bandwidth up to ~100GB/s. 
Although the chiplet will improve performance and shift arithmetic intensity of both kernels towards the ridge point, 
the memory demand is so high that I expect the kernels will still be memory bound when accelerated.


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
