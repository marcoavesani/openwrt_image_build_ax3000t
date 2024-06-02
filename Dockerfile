#FROM golang

#RUN go get github.com/aktau/github-release

#FROM centos:7

#COPY --from=0 /go/bin/github-release /usr/local/bin/

#ADD wandisco.repo /etc/yum.repos.d/

#RUN yum install -y yum-plugin-ovl subversion git gawk gettext time \
#		which ncurses-devel zlib-devel openssl-devel libxslt wget \
#		centos-release-scl && \
#	yum group install -y "Development Tools" && \
#	yum install -y rh-python38 && \
#	yum clean all
#
#WORKDIR /src



#ADD start.sh /src/

#CMD ["/src/start.sh"]

FROM openwrt/imagebuilder
RUN wget https://github.com/github-release/github-release/releases/latest/download/linux-amd64-github-release.bz2 
RUN bzip2 -d linux-amd64-github-release.bz2 
RUN	chmod +x ./linux-amd64-github-release 
USER root
RUN cp ./linux-amd64-github-release /usr/bin/github-release
RUN apt-get update && apt-get install -y zstd 



ENV GIT_REPO=marcoavesani/openwrt_image_build_ax3000t

COPY . .
RUN make .
CMD bash build_ax3000t.sh
#CMD python /app/app.py
