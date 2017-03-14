.PHONY: efs dataloader tensorflow all clean

CHARTS := efs dataloader tensorflow

all: efs dataloader tensorflow

efs: build-efs

dataloader: build-dataloader

tensorflow: build-tensorflow

distributed-cnn: build-distributed-cnn

clean:
	$(shell rm -f *.tgz)
	echo "Removed all temporary files and packages"

build-%:
	if [ -f $*/Makefile ]; then make -C $*; fi
	if [ -f $*/requirements.yaml ]; then helm dep up $*; fi
	helm lint $*
	helm package $*
