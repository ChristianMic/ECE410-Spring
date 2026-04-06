1. What are you trying to do? Articulate your objectives using absolutely no jargon. 
	I am trying to develop a HDL description co-processor chiplet that will accelerate the CNN algorithm MobileNetV2. 
	I will analyse the algorithm and the developed HDL description to determine how to accelerate the kernel of the 
	algorithm. The chiplet will be able to interface to a host system.
	
2. How is it done today, and what are the limits of current practice? 
	Today, CNNs are accelerated 2.5D/3D heterogenous integration and task/data-level paraellelism via partitioning layers (also utilizing SDM).
	Additional method include optimization of multiple chiplet communication and utilizing dedicated memory hierarchies to skip unnecessary computations.
	
	One major limit of optimization with chiplets for this kind of algorithm is that the latency between chiplets is higher than with a single chip.
	If multiple high-performance chiplets are utilized, the system struggles with voltage drops and thermal issues
	

3. What is new in your approach and why do you think it will be succesful? 
	I'm not sure if what I am doing is new, but instead of multiple chiplets I will be utilizing only one. Additionally,
	I think going the route of having the chiplet skip unnecessary computations would be where I will find most success. However,
	my knowledge on this topic and how to implement/test it is very limited so I don't have a concrete answer to this.
