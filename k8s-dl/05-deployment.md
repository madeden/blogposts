# Deploying!!
## Deploying Tensorflow

At last!!

Let's assume you have 

* prepared your my-values.yaml file
* Added tensorboard.yourdomain.com and serving.yourdomain.com DNS records pointing to the workers
* Have deployed the dataloader

Then you can just do: 

```
helm install tensorflow --name tensorflow --values /path/to/my-values.yaml --debug
```

and watch your cluster start. After a few minutes, you can go to your tensorboard and you should see: 

## A few words before concluding

To prepare this blog I worked on 2 models: Imagenet and a Distributed CNN from a workshop Google made last August. The Distributed CNN is nice because it uses a small dataset, therefore works very nicely and quickly OOTB. 

Imagenet is the one I would really have loved to see working, and all the images are meant to leverage it. Unfortunately at this stage, everything starts nicely, but it doesn't seem to actually train. PS and workers start, then do nothing without failing, and do not output any logs. I'm working on it, but I didn't want to have you wait too long for the post... 

Contact me in PMs to discuss and if you'd like to experiment with it or share ideas to fix this, I will gladly mention your help :)

