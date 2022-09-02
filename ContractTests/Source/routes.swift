import Vapor

func routes(_ app: Application) throws {
    let sdkController = SdkController()
    try app.register(collection: sdkController)
}
