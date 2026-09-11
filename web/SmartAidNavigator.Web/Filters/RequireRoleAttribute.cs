using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using SmartAidNavigator.Web.Helpers;

namespace SmartAidNavigator.Web.Filters;

public class RequireRoleAttribute : ActionFilterAttribute
{
    private readonly string _role;

    public RequireRoleAttribute(string role)
    {
        _role = role;
    }

    public override void OnActionExecuting(ActionExecutingContext context)
    {
        var userId = context.HttpContext.Session.GetString(SessionKeys.UserId);
        if (string.IsNullOrEmpty(userId))
        {
            var returnUrl = context.HttpContext.Request.Path + context.HttpContext.Request.QueryString;
            context.Result = new RedirectToActionResult("Login", "Account", new { returnUrl });
            return;
        }

        var rolesCsv = context.HttpContext.Session.GetString(SessionKeys.Roles) ?? "";
        var roles = rolesCsv.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        if (!roles.Contains(_role))
        {
            context.Result = new ForbidResult(); // 403
            return;
        }

        base.OnActionExecuting(context);
    }
}
