Config = {}

Config.Language = 'fr'

Config.GlobalCooldown = 1800
Config.PlayerCooldown = 3600

Config.PedLocation = vector4(-3.3069, -1821.0883, 29.5433, 230.3108)
Config.PedModel = `G_M_M_ChiCold_01`
Config.VehicleSpawnPoint = vector4(14.9092, -1822.4186, 24.9666, 46.1716)

Config.VehicleModels = { 'sultan', 'sultanrs' }

Config.DrugTypes = {
    {name = 'meth', label = 'Métahmphétamine', rewardPerUnit = 60, maxAmount = 500, minAmount = 10},
}

Config.DeliveryPoints = {
    vector3(2333.5942, 2580.0249, 46.6677),
    vector3(462.7187, 3549.3616, 33.2385),
    vector3(260.3390, 3111.6589, 42.4964),
    vector3(1976.3480, 5169.3828, 47.6391),
    vector3(1729.8308, 4774.2520, 41.8302),
    vector3(2562.9038, 4639.2998, 34.0768),
    vector3(-225.7094, 6436.0488, 31.1965),
    vector3(427.0791, 6469.5527, 28.7886),
    vector3(-3178.6343, 1290.0347, 14.1351),
    vector3(-66.7471, 891.7565, 235.5546),

}

Config.TypeMoney = 'money'

Config.TimerBeforeAlert = {min = 10, max = 10}
Config.PoliceAlertDuration = {min = 10, max = 10}
Config.PoliceUpdateInterval = 10 -- Intervalle en secondes pour l'envoi de la position aux policiers
Config.PoliceBlipDuration = 5 -- Durée en secondes pendant laquelle le blip reste visible

Config.PoliceJobName = 'police'
Config.MinPolice = 0

Config.OxNotifyPosition = 'top'