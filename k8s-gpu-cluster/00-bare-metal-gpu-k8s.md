# Building a Bare Metal GPU cluster for Kubernetes (and more)

I don't know if you have ever seen one of the ![Orange Boxes](/k8s-gpu-cluster/pics/obv4.png) from Canonical, but these are pretty sleek machines. They contain 10 Intel NUCs, plus an 11th one for the management. They are used as a demonstration tool for modeling big software such as OpenStack, Hadoop, and... Kubernetes. 

Using one of these, associated with Ubuntu, MAAS (Metal As A Service) and Juju (Big Software Modeling Tool), you can essentially deploy open source "models" of complex software stack. This is extremely useful for customer demos, but also for labs, R&D departments, or just for fun. Anyone can buy one from [TranquilPC](http://cluster.engineering/ubuntu-orangebox-v4-fully-configured/) 

However, they lack a critical piece of kit that we Deep Learning lovers cherish: [nVidia GPUs](https://developer.nvidia.com/cuda-gpus)!! Even worse, Intel NUCs don't have a PCI Express port, so it's not possible to add any... 

So yeah, I guess this is the end of our dream. We can't have a sleek box with a cluster of GPUs in it. 

Actually... Intel NUCs have a M.2 NGFF port. This is essentially a PCI-e 4x port, just in a different form factor. 

And, there is [this](https://www.amazon.com/gp/product/B0182NRGYO/ref=pd_sbs_147_4?ie=UTF8&pd_rd_i=B0182NRGYO&pd_rd_r=7132S1GSAF2RZKMY56AA&pd_rd_w=WgCgh&pd_rd_wg=BAWWT&psc=1&refRID=7132S1GSAF2RZKMY56AA) which converts M.2 into PCI-e 4x. 

And also [that](https://www.amazon.com/Express-PCI-E-Female-Riser-Cable/dp/B00CJE0KJ6/ref=sr_1_1?s=pc&ie=UTF8&qid=1478253899&sr=1-1&keywords=pci+4x+to+16x) which converts PCI-e 4x into 16x. 

Sooo... Theoritically, we **could** build a GPU cluster. Let's try out!! 





