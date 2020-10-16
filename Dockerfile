FROM golang:1.12.9
ADD ./sample-scheduler-extender /go/bin/sample-scheduler-extender
ENTRYPOINT ["/go/bin/sample-scheduler-extender"]
EXPOSE 8888