package main

import (
	"fmt"
	"runtime"

	"github.com/dapr/nix-demo/repo-3/pkg"
	"github.com/dapr/nix-demo/repo-3/pkg/proto/hello/v1alpha1"
)

func main() {
	fmt.Println("Hello world! " + runtime.Version() + " " + pkg.New())
	v1alpha1.NewHelloServiceClient(nil)
}
