From the roofline model we can determine that the naive kernel is memory bound since it is to the left of the ridge point.  
It is memory bound because it loads every entry of each kernel once which causes high memory traffic where computations  
are waiting for data to be fetched. Tiling helps reduce DRAM traffic as it loads entries in the kernel in large sets and  
storing them into shared memory. This allows data to be reused without reloading it from DRAM memory, and reduces overall
memory traffic as an entire tile is loaded at once rather than a trickle of single entries. In the current implementation,
the tiled kernel did achieve improvement with a better arithmetic intensity, but it is still firmly memory bound. The bottle
neck is still DRAM traffic as 16384 tiles need to be loaded per matrix (32768 total) which still slows the system. If the tile  
size was increase to 32, then I believe that there will be better improvement.