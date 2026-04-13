Interface Chosen: 32-bit @ 500MHz AXI4 Stream  
Bandwidth: 2.0 GB/s

**MaxPool2D.forward**  
Total memory traffic: 149422080 bytes  
Memory throughput: 149422080 / 0.721 ~= 207 MB/s = 0.207 GB/s  
Bandwidth requirement: >207MB/s  

**MaxPool2D.backward**  
Total memory traffic: 371589120 bytes  
Memory throughput: 371589120 / 0.402 ~= 924 MB/s = 0.924GB/s   
Bandwidth requirement : >924MB/s  

Interface vs Kernel Bandwidth: Interface bandwidth is much greater than both kernel bandwidths,  
so the interface should not bound the two kernels. However, acceleration increases data transfer  
then the kernels will be bound by the interface.  

Assumed Host Platform: MCU 


