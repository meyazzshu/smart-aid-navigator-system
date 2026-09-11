using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Helpers;
using SmartAidNavigator.Web.Models;
using SmartAidNavigator.Web.ViewModels;

namespace SmartAidNavigator.Web.Controllers;

[RequireLogin]
public class DependentsController : Controller
{
    private readonly AppDbContext _db;

    public DependentsController(AppDbContext db) => _db = db;

    private void ValidateRelationshipType(string? relationshipType)
    {
        if (!RelationshipTypes.Allowed.Contains(relationshipType))
            ModelState.AddModelError(nameof(DependentUpsertVm.RelationshipType), "Invalid relationship type.");
    }

    public async Task<IActionResult> Index()
    {
        var userId = CurrentUserHelper.GetUserId(HttpContext);

        var user = await _db.Users
            .Include(u => u.Person)
            .FirstOrDefaultAsync(u => u.UserId == userId);
        if (user?.Person == null) return Forbid();

        var dependents = await _db.PersonRelationships
            .Include(r => r.RelatedPerson)
            .Where(r => r.MainPersonId == user.PersonId && r.IsActive)
            .OrderByDescending(r => r.CreatedAt)
            .ToListAsync();

        ViewBag.MainPersonName = user.Person.FullName;
        return View(dependents);
    }

    [HttpGet]
    public IActionResult Create() => View(new DependentUpsertVm());

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(DependentUpsertVm vm)
    {
        ValidateRelationshipType(vm.RelationshipType);

        if (!ModelState.IsValid) return View(vm);

        var userId = CurrentUserHelper.GetUserId(HttpContext);
        var user = await _db.Users.FirstOrDefaultAsync(u => u.UserId == userId);
        if (user == null) return Forbid();

        var person = new Person
        {
            FullName = vm.FullName.Trim(),
            IcOrPassport = string.IsNullOrWhiteSpace(vm.IcOrPassport) ? null : vm.IcOrPassport.Trim(),
            Phone = string.IsNullOrWhiteSpace(vm.Phone) ? null : vm.Phone.Trim(),
            Gender = string.IsNullOrWhiteSpace(vm.Gender) ? null : vm.Gender.Trim(),
            DateOfBirth = vm.DateOfBirth,
            AddressLine = string.IsNullOrWhiteSpace(vm.AddressLine) ? null : vm.AddressLine.Trim(),
            City = string.IsNullOrWhiteSpace(vm.City) ? null : vm.City.Trim(),
            State = string.IsNullOrWhiteSpace(vm.State) ? null : vm.State.Trim(),
            PostalCode = string.IsNullOrWhiteSpace(vm.PostalCode) ? null : vm.PostalCode.Trim(),
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        _db.Persons.Add(person);
        await _db.SaveChangesAsync();

        var relationship = new PersonRelationship
        {
            MainPersonId = user.PersonId,
            RelatedPersonId = person.PersonId,
            RelationshipType = vm.RelationshipType,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        _db.PersonRelationships.Add(relationship);
        await _db.SaveChangesAsync();

        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Edit(long id)
    {
        var userId = CurrentUserHelper.GetUserId(HttpContext);
        var user = await _db.Users.FirstOrDefaultAsync(u => u.UserId == userId);
        if (user == null) return Forbid();

        var relationship = await _db.PersonRelationships
            .Include(r => r.RelatedPerson)
            .FirstOrDefaultAsync(r => r.RelationshipId == id && r.MainPersonId == user.PersonId && r.IsActive);
        if (relationship?.RelatedPerson == null) return NotFound();

        var vm = new DependentUpsertVm
        {
            RelationshipId = relationship.RelationshipId,
            PersonId = relationship.RelatedPersonId,
            FullName = relationship.RelatedPerson.FullName,
            IcOrPassport = relationship.RelatedPerson.IcOrPassport,
            Phone = relationship.RelatedPerson.Phone,
            Gender = relationship.RelatedPerson.Gender,
            DateOfBirth = relationship.RelatedPerson.DateOfBirth,
            AddressLine = relationship.RelatedPerson.AddressLine,
            City = relationship.RelatedPerson.City,
            State = relationship.RelatedPerson.State,
            PostalCode = relationship.RelatedPerson.PostalCode,
            RelationshipType = relationship.RelationshipType
        };

        return View(vm);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(long id, DependentUpsertVm vm)
    {
        ValidateRelationshipType(vm.RelationshipType);

        if (id != vm.RelationshipId) return BadRequest();
        if (!ModelState.IsValid) return View(vm);

        var userId = CurrentUserHelper.GetUserId(HttpContext);
        var user = await _db.Users.FirstOrDefaultAsync(u => u.UserId == userId);
        if (user == null) return Forbid();

        var relationship = await _db.PersonRelationships
            .Include(r => r.RelatedPerson)
            .FirstOrDefaultAsync(r => r.RelationshipId == id && r.MainPersonId == user.PersonId && r.IsActive);
        if (relationship?.RelatedPerson == null) return NotFound();

        relationship.RelationshipType = vm.RelationshipType;
        relationship.RelatedPerson.FullName = vm.FullName.Trim();
        relationship.RelatedPerson.IcOrPassport = string.IsNullOrWhiteSpace(vm.IcOrPassport) ? null : vm.IcOrPassport.Trim();
        relationship.RelatedPerson.Phone = string.IsNullOrWhiteSpace(vm.Phone) ? null : vm.Phone.Trim();
        relationship.RelatedPerson.Gender = string.IsNullOrWhiteSpace(vm.Gender) ? null : vm.Gender.Trim();
        relationship.RelatedPerson.DateOfBirth = vm.DateOfBirth;
        relationship.RelatedPerson.AddressLine = string.IsNullOrWhiteSpace(vm.AddressLine) ? null : vm.AddressLine.Trim();
        relationship.RelatedPerson.City = string.IsNullOrWhiteSpace(vm.City) ? null : vm.City.Trim();
        relationship.RelatedPerson.State = string.IsNullOrWhiteSpace(vm.State) ? null : vm.State.Trim();
        relationship.RelatedPerson.PostalCode = string.IsNullOrWhiteSpace(vm.PostalCode) ? null : vm.PostalCode.Trim();
        relationship.RelatedPerson.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Deactivate(long id)
    {
        var userId = CurrentUserHelper.GetUserId(HttpContext);
        var user = await _db.Users.FirstOrDefaultAsync(u => u.UserId == userId);
        if (user == null) return Forbid();

        var relationship = await _db.PersonRelationships
            .FirstOrDefaultAsync(r => r.RelationshipId == id && r.MainPersonId == user.PersonId);
        if (relationship == null) return NotFound();

        relationship.IsActive = false;
        await _db.SaveChangesAsync();
        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> RegisterAsBeneficiary(long id)
    {
        var userId = CurrentUserHelper.GetUserId(HttpContext);
        var user = await _db.Users.FirstOrDefaultAsync(u => u.UserId == userId);
        if (user == null) return Forbid();

        long shelterId;
        try
        {
            shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);
        }
        catch (InvalidOperationException)
        {
            return Forbid();
        }
        var relationship = await _db.PersonRelationships
            .FirstOrDefaultAsync(r => r.RelationshipId == id && r.MainPersonId == user.PersonId && r.IsActive);
        if (relationship == null) return NotFound();

        var existing = await _db.Beneficiaries
            .AnyAsync(b => b.PersonId == relationship.RelatedPersonId && b.ShelterId == shelterId);
        if (existing) return RedirectToAction(nameof(Index));

        _db.Beneficiaries.Add(new Beneficiary
        {
            PersonId = relationship.RelatedPersonId,
            ShelterId = shelterId,
            Status = "ACTIVE",
            AdmittedAt = DateTime.UtcNow,
            CreatedAt = DateTime.UtcNow
        });
        await _db.SaveChangesAsync();

        return RedirectToAction(nameof(Index));
    }
}
