namespace SmartAidNavigator.Web.Models;

public class RouteLocationLink
{
    public long RouteLocationLinkId { get; set; }

    public string LocationType { get; set; } = ""; // NGO / SHELTER
    public long LocationId { get; set; }

    public long NodeId { get; set; }
    public MapNode? Node { get; set; }
}
