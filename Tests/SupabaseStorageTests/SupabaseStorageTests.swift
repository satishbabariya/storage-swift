import Foundation
import XCTest

@testable import SupabaseStorage

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class SupabaseStorageTests: XCTestCase {
  let storage = SupabaseStorageClient(
    url: "\(supabaseURL)/storage/v1",
    headers: [
      "Authorization": "Bearer \(apiKey)",
      "apikey": apiKey,
    ]
  )
  let bucket = "public"

  static var apiKey: String {
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU"
  }

  static var supabaseURL: String {
    "http://localhost:54321"
  }

  override func setUp() async throws {
    try await super.setUp()
    _ = try? await storage.emptyBucket(id: bucket)
    _ = try? await storage.deleteBucket(id: bucket)

    _ = try await storage.createBucket(id: bucket, options: BucketOptions(public: true))
  }

  override func tearDown() async throws {
    _ = try? await storage.emptyBucket(id: bucket)
    _ = try? await storage.deleteBucket(id: bucket)
    try await super.tearDown()
  }

  func testListBuckets() async throws {
    let buckets = try await storage.listBuckets()
    XCTAssertEqual(buckets.map(\.name), [bucket])
  }

  func testFileIntegration() async throws {
    let uploadData = try! Data(
      contentsOf: URL(
        string: "https://raw.githubusercontent.com/supabase-community/storage-swift/main/README.md"
      )!
    )

    let file = File(name: "README.md", data: uploadData, fileName: "README.md", contentType: "text/html")
    _ = try await storage.from(id: bucket).upload(
      path: "README.md", file: file, fileOptions: FileOptions(cacheControl: "3600")
    )

    let files = try await storage.from(id: bucket).list()
    XCTAssertEqual(files.map(\.name), ["README.md"])

    let downloadedData = try await storage.from(id: bucket).download(path: "README.md")
    XCTAssertEqual(downloadedData, uploadData)

    let removedFiles = try await storage.from(id: bucket).remove(paths: ["README.md"])
    XCTAssertEqual(removedFiles.map(\.name), ["README.md"])
  }

  func testGetPublicUrl() throws {
    let path = "README.md"

    let baseUrl = try storage.from(id: bucket).getPublicUrl(path: path)
    XCTAssertEqual(baseUrl.absoluteString, "\(Self.supabaseURL)/object/public/\(path)?")

    let baseUrlWithDownload = try storage.from(id: bucket).getPublicUrl(path: path, download: true)
    XCTAssertEqual(baseUrlWithDownload.absoluteString, "\(Self.supabaseURL)/object/public/\(path)?download=")

    let baseUrlWithDownloadAndFileName = try storage.from(id: bucket).getPublicUrl(path: path, download: true, fileName: "test")
    XCTAssertEqual(baseUrlWithDownloadAndFileName.absoluteString, "\(Self.supabaseURL)/object/public/\(path)?download=test")

    let baseUrlWithAllOptions = try storage.from(id: bucket).getPublicUrl(path: path, download: true, fileName: "test", options: TransformOptions(width: 300, height: 300))
    XCTAssertEqual(baseUrlWithAllOptions.absoluteString, "\(Self.supabaseURL)/render/image/public/\(path)?download=test&width=300&height=300&resize=cover&quality=80&format=origin")
  }
}
