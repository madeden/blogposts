# Having some fun with GPUs

If you follow me you know I've been playing with Tensorflow, so that would be a usecase, but I actually wanted to get some fun with it! 

So I made a quick and dirty [Helm Chart](https://github.com/madeden/charts/tree/master/claymore) for a [Ethereum Miner](https://bitcointalk.org/index.php?topic=1433925.0), along with a simple rig monitoring system called [ethmon](https://github.com/osnwt/ethmon). 

This chart will let you configure how many nodes, and how many GPU per node you want to use. Then you can also tweak the miner. For now, it only works in ETH only mode. 

Don't forget to create a values.yaml file to 

* add you own wallet (if you keep the default you'll actually pay me, which is fine :) but not necessarily your purpose),
* update the ingress xip.io endpoint to match the public IP of one of your workers or use your own DNS
* Adjust the number of workers and GPUs per worker

then 

<pre><code>
cd ~
git clone https://github.com/madeden/charts.git
cd charts
helm init
helm install claymore --name claymore --values /path/to/yourvalues.yaml
</code></pre>

By default, you'll get the 3 worker nodes, with 2 GPUs (this is to work on my rig at home) 

What do we learn from it? Well, 

* I really need to work on my tuning here per card! The P5000 and the 1060GTX have the same perf, and they also are the same as my Quadros M4000. 
* It's probably not worth it money wise. This would make me less than $100/month with this cluster, less than my electricity bill to run it. 
* There is a LOT of room for Monero mining on the CPU! I run at less than a core for the 6 workers. 
* I'll probably update it to run less workers, but with all the GPUs allocated to them. 
* But it was very fun to make. 

If you're interested you can track the evolution of my tuning [here](https://ethermine.org/miners/7bed6aaef7e957bd0d52edf04c8b6ed3409ab0df)




