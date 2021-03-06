include env_make

NS = soflo1
VERSION = 1.0
REPO = openvpn
NAME = docker-openvpn
INSTANCE = default

.PHONY: build pull push sell start stop rm release container keystore init client install

build:
	docker build -t $(NS)/$(REPO):$(VERSION) .

push:
	docker push $(NS)/$(REPO):$(VERSION)

pull:
	docker pull $(NS)/$(REPO):$(VERSION)
			
start:
	docker run -v $(OVPN_DATA):/etc/openvpn -d -p 1194:1194/udp --cap-add=NET_ADMIN --name $(NAME)-$(INSTANCE) $(RUN_FLAG) $(NS)/$(REPO):$(VERSION)

stop:
	docker stop $(NAME)-$(INSTANCE)
							
rm:
	docker rm $(NAME)-$(INSTANCE)
								
release: build
	make push -e VERSION=$(VERSION)

container:
	docker volume create --name $(OVPN_DATA)

keystore:
	docker run -v $(OVPN_DATA):/etc/openvpn --log-driver=none --rm $(NS)/$(REPO):$(VERSION) ovpn_genconfig -u udp://$(SERVER_NAME) && \
    	docker run -v $(OVPN_DATA):/etc/openvpn --log-driver=none --rm -it $(NS)/$(REPO):$(VERSION) ovpn_initpki

init:
	docker run -v $(OVPN_DATA):/etc/openvpn --log-driver=none --rm -it $(NS)/$(REPO):$(VERSION) easyrsa build-client-full $(CLIENT_NAME) nopass

client:
	 docker run -v $(OVPN_DATA):/etc/openvpn --log-driver=none --rm $(NS)/$(REPO):$(VERSION) ovpn_getclient $(CLIENT_NAME) > $(CLIENT_NAME).ovpn

install: build container keystore start init
									
default: build

backup:
	docker run --rm --volumes-from $(NAME)-$(INSTANCE) --name tmp-backup -v $(HOST_BACKUP_DIR):/backup busybox tar cvf /backup/$(NAME)-backup-$(TIMESTAMP).tar /etc/openvpn 
	cp $(HOST_BACKUP_DIR)/$(NAME)-backup-$(TIMESTAMP).tar $(HOST_BACKUP_DIR)/$(NAME)-backup-latest.tar

restore: stop 
	docker volume rm -f $(OVPN_DATA)
	docker volume create $(OVPN_DATA)
	docker run -d -v $(OVPN_DATA):/etc/openvpn -v $(HOST_BACKUP_DIR):/backup --name $(NAME) busybox /bin/sh -c "cd / && tar xvf /backup/$(NAME)-backup-latest.tar 

	start

test-restore:  
	docker volume rm -f test
	docker volume create test
	docker run -d -v test:/etc/openvpn -v $(HOST_BACKUP_DIR):/backup busybox /bin/sh -c "cd / && tar xvf /backup/$(NAME)-backup-latest.tar" 
	docker run -it -d -v test:/etc/openvpn busybox /bin/sh  
