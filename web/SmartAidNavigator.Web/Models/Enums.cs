using Microsoft.AspNetCore.Mvc;

namespace SmartAidNavigator.Web.Models;

public enum RiskLevel
{
    LOW,
    MEDIUM,
    HIGH,
    CRITICAL
}

public enum DeliveryStatus
{
    PLANNED,
    ROUTED,
    IN_TRANSIT,
    DELIVERED,
    CANCELLED
}

