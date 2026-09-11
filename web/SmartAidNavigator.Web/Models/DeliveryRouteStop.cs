namespace SmartAidNavigator.Web.Models;

public class DeliveryRouteStop
{
    public long RouteStopId { get; set; }

    public long RouteId { get; set; }
    public DeliveryRoute? Route { get; set; }

    public int StopOrder { get; set; }

    public long ShelterId { get; set; }
    public Shelter? Shelter { get; set; }

    public decimal? DistanceFromPrevKm { get; set; }
    public int? EtaFromPrevMinutes { get; set; }

    public decimal? PriorityScore { get; set; }

}
