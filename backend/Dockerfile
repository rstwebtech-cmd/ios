FROM golang:1.22-alpine AS b
WORKDIR /src
COPY . .
RUN go build -o /server .
FROM alpine:3.19
RUN apk add --no-cache ca-certificates
COPY --from=b /server /server
CMD ["/server"]
