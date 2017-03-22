# Analyzing Results

The result sheet is public and lives [here](https://docs.google.com/spreadsheets/d/1KcC5nKnbTKaFcsg8_K_p_zodq3r-haRur1-_uJqJ4iI/edit#gid=1000765034). Feel free to tap into it and let me know if you find interesting stuff in there. 

## Impact of Memory

Once the allocation is above what is necessary for ffmpeg to transcode a video, memory is a non-impacting variable at the first approximation. However, at the second level we can see a slight increase in performance in the range of 0.5 to 1% between 1 and 4GB allocated.

Nevertheless, this factor was not taken into account.

(RAM does not impact performance (or only marginally)

## Impact of CPU allocation & Pinning)


Regardless of the deployment method (AWS or Bare Metal), there is a change in behavior when allocating less or more than 1 CPU “equivalent”.

### Being below or above the line

Running CPU allocation under 1 gives the best consistency across the board. The graph shows that the variations are contained, and what we see is an average variation of less than 4% in performance.
Running jobs with CPU request <1 is optimal for concurrencyInterestingly, the heatmap shows that the worse performance is reached when ( Concurrency * CPU Counts ) ~ 1. I don’t know how to explain that behavior. Ideas?

### Being above the line

As soon as you allocate more than a CPU, concurrency directly impacts performance. Regardless of the allocation, there is an impact, with concurrency 3.5 leading to about 10 to 15% penalty. Using more workers with less cores will increase the impact, up to 40~50% at high concurrency
As the graphs show, not all concurrencies are made equal. The below graphs show duration function of concurrency for various setups. 

When concurrency is low and the performance is well profiled, then slicing hosts thanks to LXD CPU pinning is always a valid strategy. 

By default, LXD CPU-pinning in this context will systematically outperform the native scheduling of Docker and Kubernetes. 
It seems a concurrency of 2.5 per host is the point where Kubernetes allocation becomes more efficient than forcing the spread via LXD. 

However, unbounding CPU limits for the jobs will let Kubernetes use everything it can at any point in time, and result in an overall better performance.

When using this last strategy, the performance is the same regardless of the number of cores requested for the jobs. The below graph summarizes all results: 

All results: unbounding CPU cores homogenizes performanceImpact of concurrency on individual performance
Concurrency impacts performance. The below table shows the % of performance lost because of concurrency, for various setups. 
performance is impacted from 10 to 20% when concurrency is 3 or moreConclusion
In the context of transcoding or another CPU intensive task, 
If you always allocate less than 1 CPU to your pods, concurrency doesn’t impact CPU-bound performance; Still, be careful about the other aspects. Our use case doesn’t depend on memory or disk IO, yours could. 
If you know in advance your max concurrency and it is not too high, then adding more workers with LXD and CPU pinning them always gets you better performance than native scheduling via Docker. This has other interesting properties, such as dynamic resizing of workers with no downtime, and very fast provisioning of new workers. Essentially, you get a highly elastic cluster for the same number of physical nodes. Pretty awesome. 
The winning strategy is always to super provision CPU limits to the max so that every bit of performance is allocated instantly to your pods. Of course, this cannot work in every environment, so be careful when using this, and test if it fits with your use case before applying in production. 

These results are in AWS, where there is a hypervisor between the metal and the units. I am waiting for hardware with enough cores to complete the task. If you have hardware you’d like to throw at this, be my guest and I’ll help you run the tests.
Finally and to open up a discussion, a next step could also be to use GPUs to perform this same task. The limitation will be the number of GPUs available in the cluster. I’m waiting for some new nVidia GPUs and Dell hardware, hopefully I’ll be able to put this to the test. 

There are some unknowns that I wasn’t able to sort out. I made the result dataset of ~1900 jobs open here, so you can run your own analysis! Let me know if you find anything interesting!