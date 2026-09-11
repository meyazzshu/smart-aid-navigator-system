namespace SmartAidNavigator.Web.Models;

public class MapNode
{
    public long NodeId { get; set; }

    public string NodeName { get; set; } = "";

    public decimal Latitude { get; set; }
    public decimal Longitude { get; set; }

    public bool IsActive { get; set; } = true;
}
