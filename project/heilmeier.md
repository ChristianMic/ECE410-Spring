1. What are you trying to do? Articulate your objectives using absolutely no jargon.  
	I am trying to develop a HDL description co-processor chiplet that will accelerate a CNN algorithm with manual backpropogation. 
	The chiplet will target the kernels MaxPool2D.forward and MaxPool2D.backward for acceleration.
	
2. How is it done today, and what are the limits of current practice?  
	Today, CNNs are accelerated 2.5D/3D heterogenous integration and task/data-level paraellelism via partitioning layers (also utilizing SDM).  
	Additional method include optimization of multiple chiplet communication and utilizing dedicated memory hierarchies to skip unnecessary computations.
	
	The limiation of the current algorithm's implementation is that the kernels (MaxPool2D.forward, MaxPool2D.backward) are quite memory bound with AIs 0.000651 FLOPs/byte  
    and 0.111FLOPs/byte respectively and sit under the memory line. Additionally, both are underutilizing available bandwidth with both having a total throughput of less than 1GB/s compared  to  
    the baseline processor's 41.6GB/s bandwidth. This underutilization is likely due to the software overhead.
	

4. What is new in your approach and why do you think it will be succesful?  
    I am unsure if what I am doing is necessarily new, but I will design a chiplet that will limit memory fetch operations to DRAM, increasing arithmetic intensity shifting it closer to the ridge point.  
    This will likely be implemented in the form of a line buffer. Additionally to increase memory utilization of both kernels, I plan on implementing a comparator tree to handle all the comparisons  
    which will allow comparisons to be routed to the chip avoiding the software overhead. Both of these should be succesful as they target the two issues of the kernels: Memory underutilization  
    and low arithmetic intensity in a memory bound kernel.
