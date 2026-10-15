//
//  NativesMapper.swift
//  PCLMacCE
//

// 直接从老项目里抄的
// 这段代码现在只有上帝能看懂了.jpg

import Foundation

public enum NativesMapper {
    /// 将清单中的 natives 转换为指定架构可用的版本。
    public static func map(_ manifest: ClientManifest, to architecture: Architecture = .systemArchitecture()) -> ClientManifest {
        let natives: [ClientManifest.Library] = manifest.getNatives()
        guard !natives.isEmpty else { return manifest }

        if architecture != .arm64 {
            return mapForX64(manifest, natives: natives)
        }
        return mapForArm64(manifest, natives: natives)
    }

    /// 非 ARM64：将 LWJGL 3 的 natives 统一换为非 ARM 的 macOS 版本。
    private static func mapForX64(_ manifest: ClientManifest, natives: [ClientManifest.Library]) -> ClientManifest {
        var newLibraries: [ClientManifest.Library] = manifest.libraries
        for library in natives {
            if library.groupId.starts(with: "org.lwjgl") && library.artifactId != "lwjgl-platform" {
                newLibraries.append(setArtifact(for: library, to: "org.lwjgl:\(library.artifactId):3.3.2:natives-macos"))
            } else {
                newLibraries.append(library)
            }
        }
        return manifest.setLibraries(to: newLibraries)
    }

    /// ARM64：将 LWJGL / JNA 等库替换为 HMCL 的 macOS ARM 移植版本。
    private static func mapForArm64(_ manifest: ClientManifest, natives: [ClientManifest.Library]) -> ClientManifest {
        var newLibraries: [ClientManifest.Library] = []
        for library in manifest.getLibraries() {
            newLibraries.append(mapLibraryForArm64(library))
        }
        for library in natives {
            newLibraries.append(mapNativeLibraryForArm64(library))
        }
        return manifest.setLibraries(to: newLibraries)
    }

    /// 单个普通库的 ARM64 映射（LWJGL 3 / JNA / java-objc-bridge）。
    private static func mapLibraryForArm64(_ library: ClientManifest.Library) -> ClientManifest.Library {
        if library.groupId == "org.lwjgl", library.version.starts(with: "3."), library.version != "3.3.3" {
            if library.artifactId == "lwjgl-glfw" {
                return setArtifact(for: library, to: "org.glavo.hmcl.mmachina:lwjgl-glfw:3.3.1-mmachina.1", in: APIEndpoints.MavenCentral.root)
            }
            return setVersion(for: library, to: "3.3.1")
        }
        if library.groupId == "net.java.dev.jna", library.version == "4.4.0" {
            return setVersion(for: library, to: "5.14.0")
        }
        if library.groupId == "ca.weblite", library.artifactId == "java-objc-bridge" {
            return setArtifact(for: library, to: "org.glavo.hmcl.mmachina:java-objc-bridge:1.1.0-mmachina.1", in: APIEndpoints.MavenCentral.root)
        }
        return library
    }

    /// 单个 natives 库的 ARM64 映射。
    private static func mapNativeLibraryForArm64(_ library: ClientManifest.Library) -> ClientManifest.Library {
        if library.groupId == "org.lwjgl", library.version.starts(with: "3."), library.version != "3.3.3" {
            return setArtifact(for: library, to: "org.lwjgl:\(library.artifactId):3.3.1:natives-macos-arm64")
        }
        if library.groupId == "org.lwjgl.lwjgl", library.artifactId == "lwjgl-platform" {
            return setArtifact(for: library, to: "org.glavo.hmcl:lwjgl2-natives:2.9.3-rc1-osx-arm64", in: APIEndpoints.MavenCentral.root)
        }
        if library.groupId == "ca.weblite", library.artifactId == "java-objc-bridge" {
            return setArtifact(for: library, to: "org.glavo.hmcl.mmachina:java-objc-bridge:1.1.0-mmachina.1", in: APIEndpoints.MavenCentral.root)
        }
        return library
    }

    private static func setArtifact(for library: ClientManifest.Library, to name: String, in urlRoot: URL = APIEndpoints.MojangLibraries.root) -> ClientManifest.Library {
        log("已将 \(library.name) 转换为 \(name)")
        let path: String = MavenCoordinateUtils.path(of: name)
        return .init(
            name: name,
            artifact: .init(path: path, sha1: nil, size: nil, url: urlRoot.appending(path: path)),
            rules: library.rules,
            isNativeLibrary: library.isNativesLibrary
        )
    }

    private static func setVersion(for library: ClientManifest.Library, to version: String) -> ClientManifest.Library {
        var coord: MavenCoordinateUtils.MavenCoordinate = .parse(coord: library.name)
        coord.version = version
        return setArtifact(for: library, to: coord.name)
    }
}
