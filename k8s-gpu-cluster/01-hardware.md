# Single Node NUC + GPU

Before investing in a cluster, I did a little tryout with a single node... 

I happened to own a NUC from the previous generation (NUC5i7SYH), which is essentially a Core i7, which I loaded with 16GB DDR3, and a small 120GB SSD. I also had an old Radeon 7870, good enough to validate that the system would load and recognize the card. 

I just had to buy

* a PSU: for this, I found that the [Corsair AX1500i](http://www.corsair.com/en/ax1500i-digital-atx-power-supply-1500-watt-fully-modular-psu) was the best deal on the market, capable of powering up to 10 GPUs!! Perfect if I wanted to scale this with more nodes, while a bit expensive to start with.
* Adapters: 
  * [M.2 to PCI-e 4x](https://www.amazon.com/gp/product/B0182NRGYO/ref=pd_sbs_147_4?ie=UTF8&pd_rd_i=B0182NRGYO&pd_rd_r=7132S1GSAF2RZKMY56AA&pd_rd_w=WgCgh&pd_rd_wg=BAWWT&psc=1&refRID=7132S1GSAF2RZKMY56AA) which converts M.2 into PCI-e 4x. 
  * [Riser 4x -> 16x](https://www.amazon.com/Express-PCI-E-Female-Riser-Cable/dp/B00CJE0KJ6/ref=sr_1_1?s=pc&ie=UTF8&qid=1478253899&sr=1-1&keywords=pci+4x+to+16x) 

I pass on the screen and various normal requirements that everyone doing this would have anyway.

There you go, ![the NUC, PSU and Card booting Ubuntu](/pics/nuc-external-card.jpg)

What is interesting: 

* You can notice on the pic that the screen is connected via the display port from the Radeon, so it is active and recognized as the default GPU
* There is a [hack](http://www.instructables.com/id/How-to-power-up-an-ATX-Power-Supply-without-a-PC/) to activate power on a PSU without having it connected to a "real" motherboard. Thanks to Michael Iatrou (@iatrou) for pointing me there. 

At this point, we have proof it is possible, it's time to start building a real cluster. 

# Scaling out! 

Now that we know it is possible, we will build a 6 nodes cluster with 2 management nodes, and 4 GPU compute workers. 

## Bill of Material

For each of the workers, I acquired: 

* [Intel NUC6i5RYH](https://www.amazon.es/gp/product/B018Q0GN60/ref=oh_aui_detailpage_o01_s00?ie=UTF8&psc=1): 420€, latest version, supports up to 32GB RAM. Note that I discovered later to my great disappointment that not all NUCs have AMT enabled by default. Would you want to do something closer to the Orange Box with complete automation of the power cycle, you'd need to buy the older NUC5i5MYHE, which is the only reference with vPro (beside the board itself). More info [here](http://www.intel.com/content/www/us/en/nuc/nuc-comparison.html)
* RAM: [32GB DDR4 from Corsair](https://www.amazon.es/gp/product/B017UC3O76/ref=oh_aui_detailpage_o02_s00?ie=UTF8&psc=1), 200€
* SSD: [500GB Sandisk Ultra II](https://www.amazon.es/gp/product/B00M8ABFX6/ref=oh_aui_detailpage_o02_s00?ie=UTF8&psc=1), 130€
* Video Card: [nVidia GTX1060 6GB](https://www.amazon.es/gp/product/B01IPFN7UQ/ref=oh_aui_detailpage_o06_s00?ie=UTF8&psc=1), 314€
* Adapters
  * [M.2 to PCI-e 4x](https://www.amazon.com/gp/product/B0182NRGYO/ref=pd_sbs_147_4?ie=UTF8&pd_rd_i=B0182NRGYO&pd_rd_r=7132S1GSAF2RZKMY56AA&pd_rd_w=WgCgh&pd_rd_wg=BAWWT&psc=1&refRID=7132S1GSAF2RZKMY56AA): Very variable, about 15€
  * [Riser 4x -> 16x](https://www.amazon.com/Express-PCI-E-Female-Riser-Cable/dp/B00CJE0KJ6/ref=sr_1_1?s=pc&ie=UTF8&qid=1478253899&sr=1-1&keywords=pci+4x+to+16x): also variable, around 10€
  * [4x Extender](https://www.amazon.es/hembra-adaptador-extensi%C3%B3n-cuprof%C3%B3sforo-Flexible/dp/B00UBUCES0/ref=sr_1_cc_2?s=aps&ie=UTF8&qid=1478276213&sr=1-2-catcorr&keywords=pci+4x+extender): about 7€

In total we have a bill a little over than 1.000€ per node, on top of which we need to add:

* Management nodes: 2x of the same above NUCs but without the GPU and with a smaller SSD (actually M.2), so that is ~1.400€ more
* PSU: [Corsair AX1500i](http://www.corsair.com/en/ax1500i-digital-atx-power-supply-1500-watt-fully-modular-psu), 473€
* Switch: [Netgear GS108PE](https://www.amazon.es/Netgear-GS108PE-300EUS-ProSAFE-Ethernet-garant%C3%ADa/dp/B00LMXBOG8/ref=sr_1_20?s=computers&ie=UTF8&qid=1478268416&sr=1-20&keywords=8+puertos+gigabit), 100€. You can take a lower end switch, I had one available that's all. I didn't do anything funky on the network side. 
* Raspberry Pi: Anything with 32GB micro SD, let's count 100€ for the whole thing with bells and whistles
* Spacers & accessories: 
  * [Large spacers for the boards M3x50mm](https://www.amazon.es/gp/product/B00AO40WT6/ref=oh_aui_detailpage_o05_s00?ie=UTF8&psc=1)
  * [Small spacers for the boards M3x10mm](https://www.amazon.es/gp/product/B00AH8D1HO/ref=oh_aui_detailpage_o00_s00?ie=UTF8&psc=1)
  * [ATX PSU Switch](https://www.amazon.es/gp/product/B00NB3E2N4/ref=oh_aui_detailpage_o06_s00?ie=UTF8&psc=1)
  * [M3 Hexa screws](https://www.amazon.es/gp/product/B018TH1NZ6/ref=oh_aui_detailpage_o00_s00?ie=UTF8&psc=1)
  * 10mm M3 screws (no link)

which are a little over 2.100€ for the management part. 

As comparison points, 

* The Zotac Zbox Magnus EN980 loaded with 16GB RAM and a proper SSD is about 2.500€, with a GTX980 (but operating at 16x). But it's watercooled, so I guess the coolness is worth the price :)
* Amazon g2.2xlarge instances with 1x nVidia K20s, today slower than a GTX1060 is about 50€/day so the break even on one node is at 20 days!

## Physical layout

The GPU do not fit into the NUCs case, so we have to "explode" them. We'll use a single 3mm PEC sheet, 140x297mm. 

On one side, we attach the GPU so the power connector is visible at the bottom, and the PCI-e port just slightly rises over the edge. The holes are 2.8mm so that the M3 goes through but you need to screw them a little bit and they don't move. 

![GPU Side](/pics/video-card-view.jpg)

On the other side, we drill the fixation holes fro SSD and Intel NUC so that the PCI-e riser cable is aligned in front of the PCI-e port of the GPU. You'll also have to drill the SSD metal support a little bit. 

![NUC Side](/pics/nuc-view.jpg)

As you can see on the picture, we place the riser between the PEC and the NUC

![PSU Cables](/pics/nuc-view.jpg)

## Cluster

We repeat the operation 4 times for each node. Then using our 50mm M3 hexa, we attach them with 3 screws between each "blade" to obtain

![Cluster - NUC Side](/pics/cluster-view-top-side.jpg)

![Cluster - NUC Side](/pics/cluster-view-cpu-side.jpg)

![Cluster - GPU Side](/pics/cluster-view-gpu-side.jpg)

![Cluster - GPU Side](/pics/cluster-view-close-up-gpu-side.jpg)

![Cluster - GPU Side](/pics/cluster-view-close-up-cpu-side.jpg)

Now we can plug the network, and power and we are good to go

## Non GPU nodes

Remember we have 2 nodes that do not have GPU for management perspectives. For now I just stripped them appart from their case and I will see later how to attach them nicely to the rest. I think 2 can fit on a single PVC board so that might be an option. 

We'll see but right now I want to test all the things!! 

# Next Steps

Giving life to our cluster will require quite a bit of work on the software side. 

We could just start the nodes and install everything manually, but that would really not be fun. 6 nodes, say 2 or 3 hours on each (to learn all the things about clusters and networking and other things) so that would make it say a couple of days to make it work.

Instead of that, we will install some management tooling and see the benefits when we need to re-install our cluster

My choice for this is MAAS (Metal As A Service), a tool specifically designed to manage bare metal, which already powers the Ubuntu Orange Box. I really want to see if it fits on a Raspberry Pi and if it "just works"

Then to deploy, we will be using [Juju](https://jujucharms.com), the tool that also powers the Orange Box and can deliver the Canonical Distribution of Kubernetes on Bare Metal (or in the cloud) regardless.
