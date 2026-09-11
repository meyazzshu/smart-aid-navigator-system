namespace SmartAidNavigator.Web.Models;

public class MapEdge
{
    public long EdgeId { get; set; }

    public long FromNodeId { get; set; }
    public MapNode? FromNode { get; set; }

    public long ToNodeId { get; set; }
    public MapNode? ToNode { get; set; }

    public decimal DistanceKm { get; set; }
    public int EstimatedMinutes { get; set; }

    public bool IsBidirectional { get; set; } = true;
    public bool IsActive { get; set; } = true;
}
