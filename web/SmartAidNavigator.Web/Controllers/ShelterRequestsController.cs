using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Helpers;
using SmartAidNavigator.Web.Models;
using SmartAidNavigator.Web.ViewModels;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("SHELTER_MANAGER")]
public class ShelterRequestsController : Controller
{
    private readonly AppDbContext _db;

    public ShelterRequestsController(AppDbContext db)
    {
        _db = db;
    }

    public async Task<IActionResult> Index(string? search, string? status, string? sortBy)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        search = string.IsNullOrWhiteSpace(search) ? null : search.Trim();
        status = string.IsNullOrWhiteSpace(status) ? null : status.Trim().ToUpper();
        sortBy = string.IsNullOrWhiteSpace(sortBy) ? "newest" : sortBy.Trim().ToLower();

        var allRows = await _db.ShelterRequests
            .Include(x => x.User)
                .ThenInclude(x => x!.Person)
            .Include(x => x.Dependents)
            .Where(x => x.ShelterId == shelterId)
            .Select(x => new ShelterRequestListVm
            {
                RequestId = x.RequestId,
                FullName = x.User != null && x.User.Person != null
                    ? x.User.Person.FullName ?? ""
                    : "",
                Phone = x.User != null && x.User.Person != null
                    ? x.User.Person.Phone
                    : null,
                Email = x.User != null && x.User.Person != null
                    ? x.User.Person.Email
                    : null,
                TotalPeople = x.TotalPeople,
                Status = x.Status,
                CreatedAt = x.CreatedAt,
                DependentCount = x.Dependents.Count
            })
            .ToListAsync();

        var rows = allRows.AsEnumerable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            rows = rows.Where(x =>
                x.FullName.Contains(search, StringComparison.OrdinalIgnoreCase) ||
                (x.Phone ?? "").Contains(search, StringComparison.OrdinalIgnoreCase) ||
                (x.Email ?? "").Contains(search, StringComparison.OrdinalIgnoreCase) ||
                x.RequestId.ToString().Contains(search, StringComparison.OrdinalIgnoreCase));
        }

        if (!string.IsNullOrWhiteSpace(status))
        {
            rows = rows.Where(x => x.Status == status);
        }

        rows = sortBy switch
        {
            "oldest" => rows.OrderBy(x => x.CreatedAt),
            "name-asc" => rows.OrderBy(x => x.FullName),
            "name-desc" => rows.OrderByDescending(x => x.FullName),
            "people-high" => rows.OrderByDescending(x => x.TotalPeople),
            "people-low" => rows.OrderBy(x => x.TotalPeople),
            "pending" => rows.OrderByDescending(x => x.Status == "PENDING"),
            "confirmed" => rows.OrderByDescending(x => x.Status == "CONFIRMED"),
            "arrived" => rows.OrderByDescending(x => x.Status == "ARRIVED"),
            "cancelled" => rows.OrderByDescending(x => x.Status == "CANCELLED"),
            _ => rows.OrderByDescending(x => x.CreatedAt)
        };

        return View(new ShelterRequestIndexVm
        {
            Search = search,
            Status = status,
            SortBy = sortBy,

            TotalCount = allRows.Count,
            PendingCount = allRows.Count(x => x.Status == "PENDING"),
            ConfirmedCount = allRows.Count(x => x.Status == "CONFIRMED"),
            ArrivedCount = allRows.Count(x => x.Status == "ARRIVED"),
            CancelledCount = allRows.Count(x => x.Status == "CANCELLED"),

            Rows = rows.ToList()
        });
    }

    public async Task<IActionResult> Details(long id)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var request = await _db.ShelterRequests
            .Include(x => x.Shelter)
            .Include(x => x.User)
                .ThenInclude(x => x!.Person)
            .Include(x => x.Dependents)
                .ThenInclude(x => x.Relationship)
                    .ThenInclude(x => x!.RelatedPerson)
            .FirstOrDefaultAsync(x => x.RequestId == id && x.ShelterId == shelterId);

        if (request == null) return NotFound();

        return View(new ShelterRequestDetailVm
        {
            Request = request,
            Counts = new RequestCountsEditVm
            {
                RequestId = request.RequestId,
                BabiesMale = request.BabiesMale,
                BabiesFemale = request.BabiesFemale,
                KidsMale = request.KidsMale,
                KidsFemale = request.KidsFemale,
                AdultMale = request.AdultMale,
                AdultFemale = request.AdultFemale
            },
            NewDependent = new AddRequestDependentVm
            {
                RequestId = request.RequestId
            }
        });
    }

    [HttpPost("/ShelterRequests/UpdateCounts")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> UpdateCounts([Bind(Prefix = "Counts")] RequestCountsEditVm vm)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var request = await _db.ShelterRequests
            .FirstOrDefaultAsync(x => x.RequestId == vm.RequestId && x.ShelterId == shelterId);

        if (request == null) return NotFound();

        if (request.Status == "ARRIVED")
        {
            TempData["Error"] = "Arrived request cannot be edited.";
            return RedirectToAction(nameof(Details), new { id = vm.RequestId });
        }

        request.BabiesMale = Math.Max(0, vm.BabiesMale);
        request.BabiesFemale = Math.Max(0, vm.BabiesFemale);
        request.KidsMale = Math.Max(0, vm.KidsMale);
        request.KidsFemale = Math.Max(0, vm.KidsFemale);
        request.AdultMale = Math.Max(0, vm.AdultMale);
        request.AdultFemale = Math.Max(0, vm.AdultFemale);

        request.TotalPeople =
            request.BabiesMale +
            request.BabiesFemale +
            request.KidsMale +
            request.KidsFemale +
            request.AdultMale +
            request.AdultFemale;

        await _db.SaveChangesAsync();

        TempData["Success"] = "Request headcount updated.";
        return RedirectToAction(nameof(Details), new { id = vm.RequestId });
    }

    [HttpPost("/ShelterRequests/AddDependent")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> AddDependent([Bind(Prefix = "NewDependent")] AddRequestDependentVm vm)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var request = await _db.ShelterRequests
            .Include(x => x.User)
            .FirstOrDefaultAsync(x => x.RequestId == vm.RequestId && x.ShelterId == shelterId);

        if (request == null) return NotFound();

        if (request.Status == "ARRIVED")
        {
            TempData["Error"] = "Arrived request cannot be edited.";
            return RedirectToAction(nameof(Details), new { id = vm.RequestId });
        }

        if (!ModelState.IsValid)
        {
            TempData["Error"] = "Please fill in dependent name correctly.";
            return RedirectToAction(nameof(Details), new { id = vm.RequestId });
        }

        var mainPersonId = request.User!.PersonId;

        var gender = (vm.Gender ?? "").Trim().ToUpperInvariant();

        if (gender != "MALE" && gender != "FEMALE")
        {
            TempData["Error"] = "Please select dependent gender first.";
            return RedirectToAction(nameof(Details), new { id = vm.RequestId });
        }

        var age = PersonHelper.CalculateAge(vm.DateOfBirth);

        if (!age.HasValue)
        {
            TempData["Error"] = "Please enter dependent date of birth first.";
            return RedirectToAction(nameof(Details), new { id = vm.RequestId });
        }

        var existingDependents = await _db.ShelterRequestDependents
            .Include(x => x.Relationship)
                .ThenInclude(x => x!.RelatedPerson)
            .Where(x => x.RequestId == vm.RequestId)
            .ToListAsync();

        var maleUsed = 0;
        var femaleUsed = 0;


        foreach (var dep in existingDependents)
        {
            var depGender = (dep.Relationship?.RelatedPerson?.Gender ?? "").Trim().ToUpperInvariant();

            if (depGender == "MALE") maleUsed++;
            else if (depGender == "FEMALE") femaleUsed++;
        }

        var maleAllowed = request.BabiesMale + request.KidsMale + request.AdultMale;
        var femaleAllowed = request.BabiesFemale + request.KidsFemale + request.AdultFemale;

        Person? person = null;

        var ic = string.IsNullOrWhiteSpace(vm.IcOrPassport) ? null : vm.IcOrPassport.Trim();
        var email = string.IsNullOrWhiteSpace(vm.Email) ? null : vm.Email.Trim().ToLower();

        if (!string.IsNullOrWhiteSpace(ic))
            person = await _db.Persons.FirstOrDefaultAsync(x => x.IcOrPassport == ic);

        if (person == null && !string.IsNullOrWhiteSpace(email))
            person = await _db.Persons.FirstOrDefaultAsync(x => x.Email == email);

        if (person == null)
        {
            person = new Person
            {
                FullName = vm.FullName.Trim(),
                IcOrPassport = ic,
                Phone = string.IsNullOrWhiteSpace(vm.Phone) ? null : vm.Phone.Trim(),
                Email = email,
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
        }

        if (person.PersonId == mainPersonId)
        {
            TempData["Error"] = "Requester cannot be added as their own dependent.";
            return RedirectToAction(nameof(Details), new { id = vm.RequestId });
        }

        var relationshipType = string.IsNullOrWhiteSpace(vm.RelationshipType)
            ? "OTHER"
            : vm.RelationshipType.Trim().ToUpperInvariant();

        var relationship = await _db.PersonRelationships
            .FirstOrDefaultAsync(x =>
                x.MainPersonId == mainPersonId &&
                x.RelatedPersonId == person.PersonId &&
                x.RelationshipType == relationshipType);

        if (relationship == null)
        {
            relationship = new PersonRelationship
            {
                MainPersonId = mainPersonId,
                RelatedPersonId = person.PersonId,
                RelationshipType = relationshipType,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };

            _db.PersonRelationships.Add(relationship);
            await _db.SaveChangesAsync();
        }

        var alreadyAssigned = await _db.ShelterRequestDependents
            .AnyAsync(x => x.RequestId == vm.RequestId && x.RelationshipId == relationship.RelationshipId);

        if (!alreadyAssigned)
        {
            _db.ShelterRequestDependents.Add(new ShelterRequestDependent
            {
                RequestId = vm.RequestId,
                RelationshipId = relationship.RelationshipId,
                CreatedAt = DateTime.UtcNow
            });

            var birthYear = vm.DateOfBirth!.Value.Year;
            var normalizedGender = (vm.Gender ?? "").Trim().ToUpperInvariant();

            if (birthYear >= 2023)
            {
                if (normalizedGender == "MALE")
                    request.BabiesMale += 1;
                else if (normalizedGender == "FEMALE")
                    request.BabiesFemale += 1;
            }
            else if (birthYear >= 2008 && birthYear <= 2022)
            {
                if (normalizedGender == "MALE")
                    request.KidsMale += 1;
                else if (normalizedGender == "FEMALE")
                    request.KidsFemale += 1;
            }
            else
            {
                if (normalizedGender == "MALE")
                    request.AdultMale += 1;
                else if (normalizedGender == "FEMALE")
                    request.AdultFemale += 1;
            }

            request.TotalPeople =
                request.BabiesMale +
                request.BabiesFemale +
                request.KidsMale +
                request.KidsFemale +
                request.AdultMale +
                request.AdultFemale;

            // add 1 to shelter current occupancy
            var shelter = await _db.Shelters.FirstOrDefaultAsync(x => x.ShelterId == shelterId);
            if (shelter != null)
            {
                shelter.CurrentOccupancy += 1;
            }

            await _db.SaveChangesAsync();
        }

        TempData["Success"] = "Dependent added to request.";
        return RedirectToAction(nameof(Details), new { id = vm.RequestId });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> RemoveDependent(long requestDependentId, long requestId)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var request = await _db.ShelterRequests
            .FirstOrDefaultAsync(x => x.RequestId == requestId && x.ShelterId == shelterId);

        if (request == null) return NotFound();

        var row = await _db.ShelterRequestDependents
            .Include(x => x.Relationship)
            .FirstOrDefaultAsync(x => x.RequestDependentId == requestDependentId && x.RequestId == requestId);

        if (row != null)
        {
            var personId = row.Relationship?.RelatedPersonId;

            _db.ShelterRequestDependents.Remove(row);

            request.TotalPeople = Math.Max(0, request.TotalPeople - 1);

            var shelter = await _db.Shelters.FirstOrDefaultAsync(x => x.ShelterId == shelterId);
            if (shelter != null)
            {
                shelter.CurrentOccupancy = Math.Max(0, shelter.CurrentOccupancy - 1);
            }

            if (personId.HasValue)
            {
                var beneficiary = await _db.Beneficiaries
                    .FirstOrDefaultAsync(x =>
                        x.PersonId == personId.Value &&
                        x.ShelterId == shelterId &&
                        x.Status == "ACTIVE");

                if (beneficiary != null)
                {
                    beneficiary.Status = "DISCHARGED";
                    beneficiary.DischargedAt = DateTime.UtcNow;
                }
            }

            await _db.SaveChangesAsync();
        }

        TempData["Success"] = "Dependent removed and shelter occupancy updated.";
        return RedirectToAction(nameof(Details), new { id = requestId });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ConfirmArrival(long id)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var request = await _db.ShelterRequests
            .Include(x => x.User)
            .Include(x => x.Dependents)
                .ThenInclude(x => x.Relationship)
            .FirstOrDefaultAsync(x => x.RequestId == id && x.ShelterId == shelterId);

        if (request == null)
        {
            return NotFound();
        }

        if (request.Status == "ARRIVED")
        {
            TempData["Error"] = "This request has already been marked as arrived.";
            return RedirectToAction(nameof(Details), new { id });
        }

        var now = DateTime.UtcNow;

        var personIds = new HashSet<long>();

        if (request.User != null)
        {
            personIds.Add(request.User.PersonId);
        }

        foreach (var dep in request.Dependents)
        {
            var relatedPersonId = dep.Relationship?.RelatedPersonId;

            if (relatedPersonId.HasValue)
            {
                personIds.Add(relatedPersonId.Value);
            }
        }

        var addedCount = 0;

        foreach (var personId in personIds)
        {
            var alreadyActive = await _db.Beneficiaries.AnyAsync(x =>
                x.PersonId == personId &&
                x.ShelterId == shelterId &&
                x.Status == "ACTIVE");

            if (alreadyActive)
            {
                continue;
            }

            _db.Beneficiaries.Add(new Beneficiary
            {
                PersonId = personId,
                ShelterId = shelterId,
                Status = "ACTIVE",
                AdmittedAt = now,
                CreatedAt = now
            });

            addedCount++;
        }

        request.Status = "ARRIVED";
        request.ConfirmedAt = now;
        request.ConfirmedUserId = CurrentUserHelper.GetUserId(HttpContext);

        await _db.SaveChangesAsync();

        var activeOccupancy = await _db.Beneficiaries
            .CountAsync(x => x.ShelterId == shelterId && x.Status == "ACTIVE");

        var shelter = await _db.Shelters.FirstOrDefaultAsync(x => x.ShelterId == shelterId);

        if (shelter != null)
        {
            shelter.CurrentOccupancy = activeOccupancy;
            await _db.SaveChangesAsync();
        }

        TempData["Success"] = $"Request marked as arrived. {addedCount} beneficiary record(s) added.";
        return RedirectToAction(nameof(Details), new { id });
    }
    
}