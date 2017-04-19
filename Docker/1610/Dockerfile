FROM ubuntu:16.10
COPY main.sh /tmp/
RUN echo "#!/bin/bash\nexit 0" > /usr/sbin/policy-rc.d
CMD ["/bin/bash"]
