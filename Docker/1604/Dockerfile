FROM ubuntu:16.04
COPY main.sh /tmp/
RUN echo "#!/bin/bash\nexit 0" > /usr/sbin/policy-rc.d
CMD ["/bin/bash"]
