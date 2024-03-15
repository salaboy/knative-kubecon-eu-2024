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

# Setup the Environment (other)

Enable glob matching if you're on zsh so you can run the `rm -v ^func.yaml`
command in the script below.
```
zetopt extended_glob
```
To make it easy to show the logs when showcasing the Lifecycle Hooks
feature, this is handy
```
logs() {
  local pod=$(kubectl get po | grep margherita | awk '{print $1}')
  kubectl logs -f $pod
}
```
(might want to explain where this command came from when you use it, or perhaps
even show creating it during the margherita "Setup Environment" section)

# Demo

Script Legend:
-  Regular text is speakers notes/explanations
-  Within text blocks, these notes have a // comment prefix
-  Commands to run are in `preformated text blocks`
-  Actions to perform bulleted
-  Example narrative is "in quotations"

Resetting environment between demo runthroughs:
```
pushd ~/src/margherita.dev/www
func delete && cd ../ && rm -rf www && mkdir www && cd $_
clear
```
`direnv allow`

## Setup Environment

You may want to skip this section, but it might be useful for anyone trying
to follow along at home later via recording.

"Some of the features I'll be showcasing are still in beta, so I am going to
set a few environment variables which will use them as defaults.  This should
make the commands coming up a little cleaner and easier to follow."

Enables the "host" builder which (faster, multi-arch, no container)

`export FUNC_ENABLE_HOST_BUILDER=true`

For "func run", set this to also use the host builder and run containerless
rather than in a container.

`export FUNC_CONTAINER=false` 

Set the "host" builder as the default when running "func deploy" later:

`export FUNC_BUILDER=host`

"These can also be configured as global settings in ~/.config/func/config.yaml,
or set per project using `direnv`.  They can also
all be set directly as flags when running the commands."

But enough preamble, let's create a Function"

## Initialize a New Function

"Let's say we want to set up a service at `margherita.dev`"
```
curl https://margherita.dev
```
"Or we can use the `https` helper to make these commands more convenient:"
```
https margherita.dev
```
"As you can see, there's nothing there yet.  There's also nothing running in
our target cluster:"
```
kubectl get nodes
```
"So let's initialize a new Go Function!"
```
func init -l go
```
"It's ready to go, and comes with a helpful example Function in Go which echoes
requests.  But rather than use the example we got when running `init`, for this
demo let's start from scratch.  The only file we really need is `func.yaml`, so
we'll delete everything else and start a fresh Go module:"
```
rm -v ^func.yaml
git init          // Note func is intended to work alongside Git/GitOps etc.
                  // with every operation declarative and colocated with the
                  // source code.
go mod init
bat go.mod        // Note the correct (and customizable) module name
```

"Now let's implement a minimal Function"

Copy-paste `f.go` as:
```
package www

import (
        "context"
        "fmt"
        "net/http"
)

type F struct{}

func New() *F { return &F{} }

func (f *F) Handle(_ context.Context, w http.ResponseWriter, r *http.Request) {
        fmt.Fprintln(w, "Hello, World!")
}
```

## Running Locally

"So now let's run this locally to see how it works using `func run`:"
```
func run
```
- Split screen (probably horizontally).  Hithertoo called Split B
```
http localhost:8080
```

## Deploying

"So we just ran our Function, and it works as expected, so let's see what
deploying it publicly looks like"
- clear the split with the results of `http` request
- ^C the running Function
```
func deploy           // Note this builds without using Podman or Docker
                      // but containerized builds using Buildpack and S2I
                      // are available, and a good choice for CI/CD
                      // Note it is building a multi-arch container
https margherita.dev  // Note the auto-provisioned HTTPS certificate
```
"And now let's watch as the magic of Knative Serving will scale the service to
zero when there are no requests"
- open source code in Split A
- watch pods in split B
```
watch "kubectl get po | grep margherita"
```
- While waiting for scale-down, can opine:

"Let's quickly note that this Function looks more like a library, or module,
than it does a web service.  It has no dependencies other than the standard
library. We can load transient state into the structure, it can handle
concurrent web requests, can have proper tests, etc.  It will be an actual
service.

And there it goes, scaling to zero. It will then scale back up when requests
are received.  And while startup times for a simple site like this is minimal,
you can also configure it to scale to a minimum of one instance, which avoids
any cold-start times, keeping one "hot"."

## Lifecycle Events

- clear distracting output in Split B

"Now we have an instance of a Function, with a constructor and a Handle method,
that is being run as one or more actual service instances in our cluster.  We
also have access to hooks for various lifecycle events.  Let's implement a
couple.

For example, a Function instance is automatically instrumented with readiness
and liveness checks. We can hook into these to provide deeper acknowledgement
of when the Function is Alive and when it is Ready to receive requests by
implementing a few methods"

- add two new methods to `F`:
```
func (f *F) Alive(_ context.Context) (bool, error) {
        fmt.Println("Liveness checked...")
        return true, nil
}

func (f *F) Ready(_ context.Context) (bool, error) {
        fmt.Println("Readiness checked...")
        return true, nil
}
```
- In the (empty) Split B:
```
func deploy
logs
```
- Explain how the logs now show that Kubernetes is checking readiness,
liveness; and how these checks are delgated to the Function instance.

"In addition we can hook into Start, Stop, and more to come."

The "More To Come", if asked, are things like "On Deploy" and "On Delete" which
allow for a single instance to perform an operation triggered by the results
of `func deploy` (on first deploy aka "create") and `func delete` to release
resources or other cleanup when a function is entirely undeployed.

## Dapr Runtime

"Once we have a running Function, it is a full network service, which can
make and receive requests, etc.  Let's demonstrate this by importing the Dapr SDK
and ..."

TODO:
- Edit source code to do something with the Dapr runtime such as
    1. Using service discovery to communicate with another Function
    2. Using the persistence API to save something to Redis and retreive it
       when spinning back up?

## Serving 

TODO: Basic serving which can be accomplished with `func deploy` for example:
- calling out how https works, 
- showing how additional instances are provisioned under load
- showing instances as they spin down
- how to set the minimum scale to 1 to avoid startup times
- demonstrating the Function instance is handling requests concurrently

## Composability

"While `func deploy` is nice, sometimes you just need a container.  For example
if you already have considerable tooling in place (ArgoCD, etc), or if you want
to explore some of the more advanced features of Knative Serving and Eventing.

In this case, simply run 'func build' and you've got a container from your
Function source which can be used as normal."

Perhaps run `func build` and point out the image name to use

"Lets use 'func build' to get a container, and use this container with some
more advanced features of Serving and Eventing"

## Serving - Advanced Topics

Use 'func build' to get a container, then do more advanced things using a
service.yaml


## Eventing

TODO: It would be nice to show a PingSource or other event source, subscribed
to by the Function by running `func subscribe`, and which does something (even
just printing to log) when an event is received.

## CI/CD

TODO: it might be worth explaining we're Git and CI/CD-first:

While this demo has shown all commands run directly from our demo machine, in 
practice it is expected that most of these commands would be run from within
CI/CD as an action performed when, for example a PR is merged.  'func' commands
which alter a Functions state are declarative, every state change expected to
be tracked in git, so your system has a known desired state, and is therefore
able to be recreated from source at any time.

## Summary

Some possible points to reiterate as summary:
1. No need for a Mainfile, flags, ENVs, etc.
2. Can be mass-unit tested
3. Can be embedded in a monolith as a simple library
4. Can be run locally, outside of a container
6. supports Subscriptions
7. Composable with systems which expect containers
5. ** Infrastructure can be updated! ** (without requiring re-release of Function)
