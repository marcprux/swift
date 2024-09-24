// RUN: %empty-directory(%t)
// RUN: split-file %s %t

// RUN: %target-swift-frontend -emit-module %t/Lib.swift -I %t \
// RUN:   -module-name Lib -package-name pkg \
// RUN:   -enable-library-evolution -swift-version 5 \
// RUN:   -O -wmo -allow-non-resilient-access -package-cmo \
// RUN:   -emit-module -emit-module-path %t/Lib.swiftmodule

// RUN: %target-sil-opt %t/Lib.swiftmodule -module-name Lib -o %t/Lib.sil

// RUN: %target-swift-frontend -emit-sil -O %t/Client.swift -I %t -package-name pkg \
// RUN: -Xllvm -sil-print-function=$s3Lib3PubCyACSicfC -o %t/InPkgClient.sil

// RUN: %target-swift-frontend -emit-sil -O %t/Client.swift -I %t \
// RUN: -Xllvm -sil-print-function=$s3Lib3PubCyACSicfC -o %t/ExtClient.sil

/// Verify functions are optimized with Package CMO.
// RUN: %FileCheck -check-prefix=CHECK-LIB %s < %t/Lib.sil

// Pub.__allocating_init(_:)
// CHECK-LIB: sil [serialized] [exact_self_class] [canonical] @$s3Lib3PubCyACSicfC : $@convention(method) (Int, @thick Pub.Type) -> @owned Pub {
// CHECK-LIB:  function_ref @$s3Lib3PubCyACSicfc : $@convention(method) (Int, @owned Pub) -> @owned Pub
// Pub.init(_:)
// CHECK-LIB: sil [serialized_for_package] [canonical] @$s3Lib3PubCyACSicfc : $@convention(method) (Int, @owned Pub) -> @owned Pub {
// CHECK-LIB:  ref_element_addr {{.*}} : $Pub, #Pub.pubVar

/// Test 1: The body of an external decl should be deserialized as Client and Lib are in the same package.
// RUN: %FileCheck -check-prefix=CHECK-INPKG %s < %t/InPkgClient.sil

// Pub.init(_:) is removed after getting lined below.
// CHECK-INPKG-NOT: @$s3Lib3PubCyACSicfc

// Pub.__allocating_init(_:)
// CHECK-INPKG: sil public_external @$s3Lib3PubCyACSicfC : $@convention(method) (Int, @thick Pub.Type) -> @owned Pub {
//   Pub.init(_:) is inlined in this block, as its body was deserialized.
// CHECK-INPKG:     ref_element_addr {{.*}} : $Pub, #Pub.pubVar

/// Test 2: The body of an external decl should NOT be deserialized as Client and Lib are NOT in the same package.
// RUN: %FileCheck -check-prefix=CHECK-EXT %s < %t/ExtClient.sil

// Pub.__allocating_init(_:)
// CHECK-EXT: sil public_external @$s3Lib3PubCyACSicfC : $@convention(method) (Int, @thick Pub.Type) -> @owned Pub {
// CHECK-EXT: alloc_ref $Pub
//   Contains a ref to Pub.init(_:), as its body was not deserialized.
// CHECK-EXT:      function_ref @$s3Lib3PubCyACSicfc : $@convention(method) (Int, @owned Pub) -> @owned Pub

// Pub.init(_:) is just a decl; does not contain the body.
// CHECK-EXT: sil @$s3Lib3PubCyACSicfc : $@convention(method) (Int, @owned Pub) -> @owned Pub

//--- Lib.swift
public class Pub {
  public var pubVar: Int = 1
  public init(_ arg: Int) {
    pubVar = arg
  }
}

//--- Client.swift
import Lib

public func test(_ arg: Int) -> Pub {
  let x = Pub(arg)
  x.pubVar = arg + 1
  return x
}
