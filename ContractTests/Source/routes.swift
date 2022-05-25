import Vapor

func routes(_ router: Router) throws {
    let sdkController = SdkController()
    router.get("/", use: sdkController.status)
    router.post("/", use: sdkController.createClient)
    router.delete("/", use: sdkController.shutdown)

    let clientRoutes = router.grouped("clients")
    clientRoutes.post(Int.parameter, use: sdkController.executeCommand)
    clientRoutes.delete(Int.parameter, use: sdkController.shutdownClient)
}
