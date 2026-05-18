As it stands from the report and analysis I was able to gather, I don't plan on changing  
much. The critical path is a total delay of 8.875ns which I atleast think is acceptable,  
but I believe an eye should be kept on it incase it becomes a hindrance to the system.  
The max fanout is an area that I think should be improved as it is driving 14-15 loads   
over the limit of 10. There are ways to improve it through changing openlane settings,   
however a concrete solution would be to edit the system verilog code itself. Improving   
this would also likely fix or atleast improve the slew violations experienced as well.  
Though, the slew violations are minor with only 0.058ns above the limit. 
