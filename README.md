# Knative KubeCon EU Paris, France 2024

Knative Maintainers Track KubeCon Paris. Demo Install. 

# Build/Install

```
./install-tools.sh
```

# Setup a Cluster

The script will create a kind cluster and install Knative Serving and friends 

```
./setup-cluster.sh
```

# Run the demo

1. Setup Environment Variables
```
direnv allow
```

2. Boostrap a 'hello' function

```
mkdir hello && cd hello
func init --language go
rm *.go # remove boilerplate code from template
```

Create function hello.go
```

```

```
func deploy
```


# Slides

- Intro.. let's look into functions
- Instance Based functions (function lifecycle)
- Deploy function to cluster (show maybe https)
- Plain http request to Dapr StateStore
    - Maybe import dapr SDK
- Serving bits
    - https
    - concurrency



