using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Models;

namespace SmartAidNavigator.Web.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<User> Users => Set<User>();
    public DbSet<Person> Persons => Set<Person>();
    public DbSet<PersonRelationship> PersonRelationships => Set<PersonRelationship>();
    public DbSet<Role> Roles => Set<Role>();
    public DbSet<UserRole> UserRoles => Set<UserRole>();

    public DbSet<Ngo> Ngos => Set<Ngo>();
    public DbSet<NgoStaff> NgoStaff => Set<NgoStaff>();

    public DbSet<Shelter> Shelters => Set<Shelter>();
    public DbSet<ShelterManager> ShelterManagers => Set<ShelterManager>();

    public DbSet<AidCategory> AidCategories => Set<AidCategory>();
    public DbSet<AidItem> AidItems => Set<AidItem>();
    public DbSet<ShelterInventory> ShelterInventory => Set<ShelterInventory>();

    public DbSet<Delivery> Deliveries => Set<Delivery>();
    public DbSet<DeliveryTracking> DeliveryTracking => Set<DeliveryTracking>();

    public DbSet<DeliveryRoute> Routes => Set<DeliveryRoute>();
    public DbSet<DeliveryRouteStop> RouteStops => Set<DeliveryRouteStop>();
    public DbSet<DeliveryItem> DeliveryItems => Set<DeliveryItem>();

    public DbSet<ShelterAssessment> ShelterAssessments => Set<ShelterAssessment>();

    public DbSet<StockTransaction> StockTransactions => Set<StockTransaction>();
    public DbSet<Beneficiary> Beneficiaries => Set<Beneficiary>();
    public DbSet<BeneficiaryNeed> BeneficiaryNeeds => Set<BeneficiaryNeed>();

    public DbSet<MapNode> MapNodes => Set<MapNode>();
    public DbSet<MapEdge> MapEdges => Set<MapEdge>();
    public DbSet<RouteLocationLink> RouteLocationLinks => Set<RouteLocationLink>();

    public DbSet<Donation> Donations => Set<Donation>();
    public DbSet<DonationItem> DonationItems => Set<DonationItem>();
    public DbSet<Donor> Donors => Set<Donor>();
    public DbSet<Payment> Payments => Set<Payment>();
    public DbSet<NgoInventory> NgoInventory => Set<NgoInventory>();

    public DbSet<PriorityCategory> PriorityCategories => Set<PriorityCategory>();
    public DbSet<ShelterRequest> ShelterRequests => Set<ShelterRequest>();
    public DbSet<ShelterRequestDependent> ShelterRequestDependents => Set<ShelterRequestDependent>();
    public DbSet<DeviceToken> DeviceTokens => Set<DeviceToken>();
    public DbSet<InventoryTransaction> InventoryTransactions => Set<InventoryTransaction>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();

    public DbSet<DeliveryGroup> DeliveryGroups => Set<DeliveryGroup>();
    public DbSet<DeliveryGroupDelivery> DeliveryGroupDeliveries => Set<DeliveryGroupDelivery>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<ShelterRequest>()
            .HasOne(x => x.ProcessedByUser)
            .WithMany()
            .HasForeignKey(x => x.ProcessedByUserId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<User>(e =>
        {
            e.ToTable("users");
            e.HasKey(x => x.UserId);
            e.Property(x => x.UserId).HasColumnName("user_id");
            e.Property(x => x.PersonId).HasColumnName("person_id");
            e.Property(x => x.PasswordHash).HasColumnName("password_hash");
            e.Property(x => x.IsActive).HasColumnName("is_active");
            e.Property(x => x.IsGuest).HasColumnName("is_guest");
            e.Property(x => x.CreatedAt).HasColumnName("created_at");

            e.HasOne(x => x.Person)
                .WithOne(x => x.User)
                .HasForeignKey<User>(x => x.PersonId);
        });

        modelBuilder.Entity<Person>(e =>
        {
            e.ToTable("persons");
            e.HasKey(x => x.PersonId);
            e.Property(x => x.PersonId).HasColumnName("person_id");
            e.Property(x => x.FullName).HasColumnName("full_name");
            e.Property(x => x.IcOrPassport).HasColumnName("ic_or_passport");
            e.Property(x => x.Phone).HasColumnName("phone");
            e.Property(x => x.Email).HasColumnName("email");
            e.Property(x => x.Gender).HasColumnName("gender");
            e.Property(x => x.DateOfBirth)
                .HasColumnName("date_of_birth")
                .HasConversion(
                    v => v.HasValue ? v.Value.ToDateTime(TimeOnly.MinValue) : (DateTime?)null,
                    v => v.HasValue ? DateOnly.FromDateTime(v.Value) : (DateOnly?)null);
            e.Property(x => x.AddressLine).HasColumnName("address_line");
            e.Property(x => x.City).HasColumnName("city");
            e.Property(x => x.State).HasColumnName("state");
            e.Property(x => x.PostalCode).HasColumnName("postal_code");
            e.Property(x => x.CreatedAt).HasColumnName("created_at");
            e.Property(x => x.UpdatedAt).HasColumnName("updated_at");
        });

        modelBuilder.Entity<PersonRelationship>(e =>
        {
            e.ToTable("person_relationships");
            e.HasKey(x => x.RelationshipId);
            e.Property(x => x.RelationshipId).HasColumnName("relationship_id");
            e.Property(x => x.MainPersonId).HasColumnName("main_person_id");
            e.Property(x => x.RelatedPersonId).HasColumnName("related_person_id");
            e.Property(x => x.RelationshipType).HasColumnName("relationship_type");
            e.Property(x => x.IsActive).HasColumnName("is_active");
            e.Property(x => x.CreatedAt).HasColumnName("created_at");

            e.HasOne(x => x.MainPerson)
                .WithMany(x => x.MainPersonRelationships)
                .HasForeignKey(x => x.MainPersonId)
                .OnDelete(DeleteBehavior.Cascade);

            e.HasOne(x => x.RelatedPerson)
                .WithMany(x => x.RelatedPersonRelationships)
                .HasForeignKey(x => x.RelatedPersonId)
                .OnDelete(DeleteBehavior.Cascade);

            e.HasIndex(x => new { x.MainPersonId, x.RelatedPersonId, x.RelationshipType })
                .IsUnique();
        });

        modelBuilder.Entity<Role>(e =>
        {
            e.ToTable("roles");
            e.HasKey(x => x.RoleId);
            e.Property(x => x.RoleId).HasColumnName("role_id");
            e.Property(x => x.RoleName).HasColumnName("role_name");
        });

        modelBuilder.Entity<UserRole>(e =>
        {
            e.ToTable("user_roles");
            e.HasKey(x => new { x.UserId, x.RoleId });

            e.Property(x => x.UserId).HasColumnName("user_id");
            e.Property(x => x.RoleId).HasColumnName("role_id");

            e.HasOne(x => x.User)
                .WithMany(x => x.UserRoles)
                .HasForeignKey(x => x.UserId);

            e.HasOne(x => x.Role)
                .WithMany(x => x.UserRoles)
                .HasForeignKey(x => x.RoleId);
        });

        modelBuilder.Entity<StockTransaction>(e =>
        {
            e.ToTable("stock_transactions_backup");
            e.HasKey(x => x.TransactionId);

            e.Property(x => x.TransactionId).HasColumnName("transaction_id");
            e.Property(x => x.ShelterId).HasColumnName("shelter_id");
            e.Property(x => x.ItemId).HasColumnName("item_id");
            e.Property(x => x.TransactionType).HasColumnName("transaction_type");
            e.Property(x => x.Quantity).HasColumnName("quantity");
            e.Property(x => x.Note).HasColumnName("note");
            e.Property(x => x.CreatedBy).HasColumnName("created_by");
            e.Property(x => x.CreatedAt).HasColumnName("created_at");

            e.HasOne(x => x.Shelter)
                .WithMany()
                .HasForeignKey(x => x.ShelterId);

            e.HasOne(x => x.Item)
                .WithMany()
                .HasForeignKey(x => x.ItemId);

            e.HasOne(x => x.CreatedByUser)
                .WithMany()
                .HasForeignKey(x => x.CreatedBy);
        });

        modelBuilder.Entity<Ngo>(e =>
        {
            e.ToTable("ngos");
            e.HasKey(x => x.NgoId);

            e.Property(x => x.NgoId).HasColumnName("ngo_id");
            e.Property(x => x.NgoName).HasColumnName("ngo_name");
            e.Property(x => x.Description).HasColumnName("description");
            e.Property(x => x.Phone).HasColumnName("phone");
            e.Property(x => x.Email).HasColumnName("email");
            e.Property(x => x.TaxExemptionNo).HasColumnName("tax_exemption_no");
            e.Property(x => x.IsTaxExempt).HasColumnName("is_tax_exempt");
            e.Property(x => x.AddressLine).HasColumnName("address_line");
            e.Property(x => x.City).HasColumnName("city");
            e.Property(x => x.State).HasColumnName("state");
            e.Property(x => x.PostalCode).HasColumnName("postal_code");
            e.Property(x => x.Latitude).HasColumnName("latitude").HasPrecision(10, 7);
            e.Property(x => x.Longitude).HasColumnName("longitude").HasPrecision(10, 7);
            e.Property(x => x.IsActive).HasColumnName("is_active");
            e.Property(x => x.CreatedAt).HasColumnName("created_at");
            e.Property(x => x.ApprovedBy).HasColumnName("approved_by");
            e.Property(x => x.ApprovedAt).HasColumnName("approved_at");


            e.HasMany(x => x.Shelters)
                .WithOne(x => x.Ngo)
                .HasForeignKey(x => x.NgoId);

            e.HasOne(x => x.ApprovedByUser)
                .WithMany()
                .HasForeignKey(x => x.ApprovedBy)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<NgoStaff>(e =>
        {
            e.ToTable("ngo_staff");
            e.HasKey(x => new { x.NgoId, x.UserId });

            e.Property(x => x.NgoId).HasColumnName("ngo_id");
            e.Property(x => x.UserId).HasColumnName("user_id");
            e.Property(x => x.StaffTitle).HasColumnName("staff_title");

            e.HasOne<User>()
                .WithMany()
                .HasForeignKey(x => x.UserId);

            e.HasOne<Ngo>()
                .WithMany()
                .HasForeignKey(x => x.NgoId);
        });

        modelBuilder.Entity<Shelter>(e =>
        {
            e.ToTable("shelters");
            e.HasKey(x => x.ShelterId);

            e.Property(x => x.ShelterId).HasColumnName("shelter_id");
            e.Property(x => x.ShelterName).HasColumnName("shelter_name");
            e.Property(x => x.NgoId).HasColumnName("ngo_id");
            e.Property(x => x.Phone).HasColumnName("phone");
            e.Property(x => x.Email).HasColumnName("email");
            e.Property(x => x.AddressLine).HasColumnName("address_line");
            e.Property(x => x.City).HasColumnName("city");
            e.Property(x => x.State).HasColumnName("state");
            e.Property(x => x.PostalCode).HasColumnName("postal_code");
            e.Property(x => x.Latitude).HasColumnName("latitude").HasPrecision(10, 7);
            e.Property(x => x.Longitude).HasColumnName("longitude").HasPrecision(10, 7);
            e.Property(x => x.Capacity).HasColumnName("capacity");
            e.Property(x => x.CurrentOccupancy).HasColumnName("current_occupancy");
            e.Property(x => x.IsActive).HasColumnName("is_active");
            e.Property(x => x.CreatedAt).HasColumnName("created_at");
            e.Property(x => x.ApprovedBy).HasColumnName("approved_by");
            e.Property(x => x.ApprovedAt).HasColumnName("approved_at");

            e.HasOne(x => x.ApprovedByUser)
                .WithMany()
                .HasForeignKey(x => x.ApprovedBy)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<ShelterManager>(e =>
        {
            e.ToTable("shelter_managers");
            e.HasKey(x => new { x.ShelterId, x.UserId });

            e.Property(x => x.ShelterId).HasColumnName("shelter_id");
            e.Property(x => x.UserId).HasColumnName("user_id");
            e.Property(e => e.StaffTitle).HasColumnName("staff_title").HasMaxLength(100);

            e.HasOne<User>()
                .WithMany()
                .HasForeignKey(x => x.UserId);

            e.HasOne<Shelter>()
                .WithMany()
                .HasForeignKey(x => x.ShelterId);
        });

        modelBuilder.Entity<AidCategory>(e =>
        {
            e.ToTable("aid_categories");
            e.HasKey(x => x.CategoryId);

            e.Property(x => x.CategoryId).HasColumnName("category_id");
            e.Property(x => x.CategoryName).HasColumnName("category_name");

            e.HasMany(x => x.Items)
                .WithOne(x => x.Category)
                .HasForeignKey(x => x.CategoryId);
        });

        modelBuilder.Entity<AidItem>(e =>
        {
            e.ToTable("aid_items");
            e.HasKey(x => x.ItemId);

            e.Property(x => x.ItemId).HasColumnName("item_id");
            e.Property(x => x.CategoryId).HasColumnName("category_id");
            e.Property(x => x.ItemName).HasColumnName("item_name");
            e.Property(x => x.Unit).HasColumnName("unit");
            e.Property(x => x.IsActive).HasColumnName("is_active");
        });

        modelBuilder.Entity<ShelterInventory>(e =>
        {
            e.ToTable("shelter_inventory");
            e.HasKey(x => x.InventoryId);

            e.Property(x => x.InventoryId).HasColumnName("inventory_id");
            e.Property(x => x.ShelterId).HasColumnName("shelter_id");
            e.Property(x => x.ItemId).HasColumnName("item_id");
            e.Property(x => x.Quantity).HasColumnName("quantity");
            e.Property(x => x.MinimumLevel).HasColumnName("minimum_level");
            e.Property(x => x.UpdatedAt).HasColumnName("updated_at");

            e.HasOne(x => x.Shelter)
                .WithMany(x => x.Inventory)
                .HasForeignKey(x => x.ShelterId);

            e.HasOne(x => x.Item)
                .WithMany(x => x.ShelterInventories)
                .HasForeignKey(x => x.ItemId);

            e.HasIndex(x => new { x.ShelterId, x.ItemId }).IsUnique();
        });

        modelBuilder.Entity<Delivery>(e =>
        {
            e.ToTable("deliveries");

            e.HasKey(x => x.DeliveryId);

            // Columns
            e.Property(x => x.DeliveryId)
                .HasColumnName("delivery_id");

            e.Property(x => x.NgoId)
                .HasColumnName("ngo_id");

            e.Property(x => x.ShelterId)
                .HasColumnName("shelter_id");

            e.Property(x => x.AssignedTo)
                .HasColumnName("assigned_to");

            e.Property(x => x.PriorityId)
                .HasColumnName("priority_id");

            e.Property(x => x.RouteId)
                .HasColumnName("route_id");

            e.Property(x => x.Status)
                .HasColumnName("status")
                .HasConversion<string>();

            e.Property(x => x.ScheduledDate)
                .HasColumnName("scheduled_date")
                .HasConversion(
                    v => v.HasValue
                        ? v.Value.ToDateTime(TimeOnly.MinValue)
                        : (DateTime?)null,
                    v => v.HasValue
                        ? DateOnly.FromDateTime(v.Value)
                        : (DateOnly?)null
                );

            e.Property(x => x.Notes)
                .HasColumnName("notes");

            e.Property(x => x.PriorityScore)
                .HasColumnName("priority_score")
                .HasPrecision(10, 2);

            e.Property(x => x.DistanceKm)
                .HasColumnName("distance_km")
                .HasPrecision(10, 2);

            e.Property(x => x.EtaMinutes)
                .HasColumnName("eta_minutes");

            e.Property(x => x.ImageLink)
                .HasColumnName("image_link");

            e.Property(x => x.CreatedAt)
                .HasColumnName("created_at");

            // Relationships
            e.HasOne(x => x.Ngo)
                .WithMany(x => x.Deliveries)
                .HasForeignKey(x => x.NgoId);

            e.HasOne(x => x.Shelter)
                .WithMany(x => x.Deliveries)
                .HasForeignKey(x => x.ShelterId);

            e.HasOne(x => x.AssignedUser)
                .WithMany()
                .HasForeignKey(x => x.AssignedTo);

            e.HasOne(x => x.Route)
                .WithMany(x => x.Deliveries)
                .HasForeignKey(x => x.RouteId);

            e.HasOne(x => x.PriorityCategory)
                .WithMany()
                .HasForeignKey(x => x.PriorityId);

        });

        modelBuilder.Entity<DeliveryItem>(e =>
        {
            e.ToTable("delivery_items");
            e.HasKey(x => x.DeliveryItemId);

            e.Property(x => x.DeliveryItemId).HasColumnName("delivery_item_id");
            e.Property(x => x.DeliveryId).HasColumnName("delivery_id");
            e.Property(x => x.ItemId).HasColumnName("item_id");
            e.Property(x => x.Quantity).HasColumnName("quantity");

            e.HasOne(x => x.Delivery)
                .WithMany(x => x.DeliveryItems)
                .HasForeignKey(x => x.DeliveryId)
                .OnDelete(DeleteBehavior.Cascade);

            e.HasOne(x => x.Item)
                .WithMany()
                .HasForeignKey(x => x.ItemId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<DeliveryTracking>(e =>
        {
            e.ToTable("delivery_tracking");
            e.HasKey(x => x.TrackingId);

            e.Property(x => x.TrackingId).HasColumnName("tracking_id");
            e.Property(x => x.DeliveryId).HasColumnName("delivery_id");

            e.Property(x => x.Status)
                .HasColumnName("status")
                .HasConversion<string>();

            e.Property(x => x.Latitude).HasColumnName("latitude").HasPrecision(10, 7);
            e.Property(x => x.Longitude).HasColumnName("longitude").HasPrecision(10, 7);
            e.Property(x => x.Note).HasColumnName("note");
            e.Property(x => x.CreatedAt).HasColumnName("created_at");

            e.HasOne(x => x.Delivery)
                .WithMany(x => x.TrackingUpdates)
                .HasForeignKey(x => x.DeliveryId);
        });

        modelBuilder.Entity<DeliveryRoute>(e =>
        {
            e.ToTable("routes");
            e.HasKey(x => x.RouteId);

            e.Property(x => x.RouteId).HasColumnName("route_id");
            e.Property(x => x.NgoId).HasColumnName("ngo_id");
            e.Property(x => x.GeneratedBy).HasColumnName("generated_by");
            e.Property(x => x.Algorithm).HasColumnName("algorithm");
            e.Property(x => x.TotalDistanceKm).HasColumnName("total_distance_km").HasPrecision(10, 2);
            e.Property(x => x.TotalEtaMinutes).HasColumnName("total_eta_minutes");
            e.Property(x => x.CreatedAt).HasColumnName("created_at");

            e.HasOne(x => x.Ngo)
                .WithMany(x => x.Routes)
                .HasForeignKey(x => x.NgoId);

            e.HasOne(x => x.GeneratedByUser)
                .WithMany()
                .HasForeignKey(x => x.GeneratedBy);
        });

        modelBuilder.Entity<DeliveryRouteStop>(e =>
        {
            e.ToTable("route_stops");
            e.HasKey(x => x.RouteStopId);

            e.Property(x => x.RouteStopId).HasColumnName("route_stop_id");
            e.Property(x => x.RouteId).HasColumnName("route_id");
            e.Property(x => x.StopOrder).HasColumnName("stop_order");
            e.Property(x => x.ShelterId).HasColumnName("shelter_id");

            e.Property(x => x.DistanceFromPrevKm).HasColumnName("distance_from_prev_km").HasPrecision(10, 2);
            e.Property(x => x.EtaFromPrevMinutes).HasColumnName("eta_from_prev_minutes");
            e.Property(x => x.PriorityScore).HasColumnName("priority_score").HasPrecision(10, 2);

            e.HasOne(x => x.Route)
                .WithMany(x => x.Stops)
                .HasForeignKey(x => x.RouteId);

            e.HasOne(x => x.Shelter)
                .WithMany(x => x.RouteStops)
                .HasForeignKey(x => x.ShelterId);

            e.HasIndex(x => new { x.RouteId, x.StopOrder }).IsUnique();
            e.HasIndex(x => new { x.RouteId, x.ShelterId }).IsUnique();
        });

        modelBuilder.Entity<ShelterAssessment>(e =>
        {
            e.ToTable("shelter_assessments");
            e.HasKey(x => x.AssessmentId);

            e.Property(x => x.AssessmentId).HasColumnName("assessment_id");
            e.Property(x => x.ShelterId).HasColumnName("shelter_id");
            e.Property(x => x.BabiesCount).HasColumnName("babies_count");
            e.Property(x => x.ElderlyCount).HasColumnName("elderly_count");

            e.Property(x => x.RiskLevel)
                .HasColumnName("risk_level")
                .HasConversion<string>();

            e.Property(x => x.SituationNotes).HasColumnName("situation_notes");
            e.Property(x => x.AssessedBy).HasColumnName("assessed_by");
            e.Property(x => x.AssessedAt).HasColumnName("assessed_at");

            e.HasOne(x => x.Shelter)
                .WithMany(x => x.Assessments)
                .HasForeignKey(x => x.ShelterId);

            e.HasOne(x => x.AssessedByUser)
                .WithMany()
                .HasForeignKey(x => x.AssessedBy);

            e.HasIndex(x => new { x.ShelterId, x.AssessedAt });
        });

        modelBuilder.Entity<Beneficiary>(e =>
        {
            e.ToTable("beneficiaries");
            e.HasKey(x => x.BeneficiaryId);

            e.Property(x => x.BeneficiaryId).HasColumnName("beneficiary_id");
            e.Property(x => x.PersonId).HasColumnName("person_id");
            e.Property(x => x.ShelterId).HasColumnName("shelter_id");
            e.Property(x => x.Status).HasColumnName("status");
            e.Property(x => x.AdmittedAt).HasColumnName("admitted_at");
            e.Property(x => x.DischargedAt).HasColumnName("discharged_at");
            e.Property(x => x.AgeAtRegistration).HasColumnName("age_at_registration");
            e.Property(x => x.CreatedAt).HasColumnName("created_at");

            e.HasOne(x => x.Shelter)
                .WithMany(x => x.Beneficiaries)
                .HasForeignKey(x => x.ShelterId);

            e.HasOne(x => x.Person)
                .WithMany(x => x.Beneficiaries)
                .HasForeignKey(x => x.PersonId);
        });

        modelBuilder.Entity<BeneficiaryNeed>(entity =>
        {
            entity.ToTable("beneficiary_needs");

            entity.HasKey(e => e.NeedId);

            entity.Property(e => e.NeedId)
                .HasColumnName("need_id");

            entity.Property(e => e.BeneficiaryId)
                .HasColumnName("beneficiary_id");

            entity.Property(e => e.ItemId)
                .HasColumnName("item_id");

            entity.Property(e => e.RequiredQuantity)
                .HasColumnName("required_quantity");

            entity.Property(e => e.Priority)
                .HasColumnName("priority");

            entity.Property(e => e.RequestStatus)
                .HasColumnName("request_status");

            entity.Property(e => e.RequestedByUserId)
                .HasColumnName("requested_by_user_id");

            entity.Property(e => e.ReviewedByUserId)
                .HasColumnName("reviewed_by_user_id");

            entity.Property(e => e.ReviewedAt)
                .HasColumnName("reviewed_at");

            entity.Property(e => e.FulfilledByUserId)
                .HasColumnName("fulfilled_by_user_id");

            entity.Property(e => e.FulfilledAt)
                .HasColumnName("fulfilled_at");

            entity.Property(e => e.RejectionReason)
                .HasColumnName("rejection_reason");

            entity.Property(e => e.Notes)
                .HasColumnName("notes");

            entity.Property(e => e.CreatedAt)
                .HasColumnName("created_at");

            entity.HasOne(e => e.Beneficiary)
                .WithMany(e => e.Needs)
                .HasForeignKey(e => e.BeneficiaryId);

            entity.HasOne(e => e.Item)
                .WithMany()
                .HasForeignKey(e => e.ItemId);

            entity.HasOne(e => e.RequestedByUser)
                .WithMany()
                .HasForeignKey(e => e.RequestedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.ReviewedByUser)
                .WithMany()
                .HasForeignKey(e => e.ReviewedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.FulfilledByUser)
                .WithMany()
                .HasForeignKey(e => e.FulfilledByUserId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<MapNode>(e =>
        {
            e.ToTable("map_nodes");
            e.HasKey(x => x.NodeId);

            e.Property(x => x.NodeId).HasColumnName("node_id");
            e.Property(x => x.NodeName).HasColumnName("node_name");
            e.Property(x => x.Latitude).HasColumnName("latitude").HasPrecision(10, 7);
            e.Property(x => x.Longitude).HasColumnName("longitude").HasPrecision(10, 7);
            e.Property(x => x.IsActive).HasColumnName("is_active");
        });

        modelBuilder.Entity<MapEdge>(e =>
        {
            e.ToTable("map_edges");
            e.HasKey(x => x.EdgeId);

            e.Property(x => x.EdgeId).HasColumnName("edge_id");
            e.Property(x => x.FromNodeId).HasColumnName("from_node_id");
            e.Property(x => x.ToNodeId).HasColumnName("to_node_id");
            e.Property(x => x.DistanceKm).HasColumnName("distance_km").HasPrecision(10, 2);
            e.Property(x => x.EstimatedMinutes).HasColumnName("estimated_minutes");
            e.Property(x => x.IsBidirectional).HasColumnName("is_bidirectional");
            e.Property(x => x.IsActive).HasColumnName("is_active");

            e.HasOne(x => x.FromNode)
                .WithMany()
                .HasForeignKey(x => x.FromNodeId)
                .OnDelete(DeleteBehavior.Restrict);

            e.HasOne(x => x.ToNode)
                .WithMany()
                .HasForeignKey(x => x.ToNodeId)
                .OnDelete(DeleteBehavior.Restrict);

            e.HasIndex(x => new { x.FromNodeId, x.ToNodeId }).IsUnique();
        });

        modelBuilder.Entity<RouteLocationLink>(e =>
        {
            e.ToTable("route_location_links");
            e.HasKey(x => x.RouteLocationLinkId);

            e.Property(x => x.RouteLocationLinkId).HasColumnName("route_location_link_id");
            e.Property(x => x.LocationType).HasColumnName("location_type");
            e.Property(x => x.LocationId).HasColumnName("location_id");
            e.Property(x => x.NodeId).HasColumnName("node_id");

            e.HasOne(x => x.Node)
                .WithMany()
                .HasForeignKey(x => x.NodeId);

            e.HasIndex(x => new { x.LocationType, x.LocationId }).IsUnique();
        });

        modelBuilder.Entity<MapNode>(e =>
        {
            e.ToTable("map_nodes");
            e.HasKey(x => x.NodeId);

            e.Property(x => x.NodeId).HasColumnName("node_id");
            e.Property(x => x.NodeName).HasColumnName("node_name");
            e.Property(x => x.Latitude).HasColumnName("latitude").HasPrecision(10, 7);
            e.Property(x => x.Longitude).HasColumnName("longitude").HasPrecision(10, 7);
            e.Property(x => x.IsActive).HasColumnName("is_active");
        });

        modelBuilder.Entity<MapEdge>(e =>
        {
            e.ToTable("map_edges");
            e.HasKey(x => x.EdgeId);

            e.Property(x => x.EdgeId).HasColumnName("edge_id");
            e.Property(x => x.FromNodeId).HasColumnName("from_node_id");
            e.Property(x => x.ToNodeId).HasColumnName("to_node_id");
            e.Property(x => x.DistanceKm).HasColumnName("distance_km").HasPrecision(10, 2);
            e.Property(x => x.EstimatedMinutes).HasColumnName("estimated_minutes");
            e.Property(x => x.IsBidirectional).HasColumnName("is_bidirectional");
            e.Property(x => x.IsActive).HasColumnName("is_active");

            e.HasOne(x => x.FromNode)
                .WithMany()
                .HasForeignKey(x => x.FromNodeId)
                .OnDelete(DeleteBehavior.Restrict);

            e.HasOne(x => x.ToNode)
                .WithMany()
                .HasForeignKey(x => x.ToNodeId)
                .OnDelete(DeleteBehavior.Restrict);

            e.HasIndex(x => new { x.FromNodeId, x.ToNodeId }).IsUnique();
        });

        modelBuilder.Entity<RouteLocationLink>(e =>
        {
            e.ToTable("route_location_links");
            e.HasKey(x => x.RouteLocationLinkId);

            e.Property(x => x.RouteLocationLinkId).HasColumnName("route_location_link_id");
            e.Property(x => x.LocationType).HasColumnName("location_type");
            e.Property(x => x.LocationId).HasColumnName("location_id");
            e.Property(x => x.NodeId).HasColumnName("node_id");

            e.HasOne(x => x.Node)
                .WithMany()
                .HasForeignKey(x => x.NodeId);

            e.HasIndex(x => new { x.LocationType, x.LocationId }).IsUnique();
        });

        modelBuilder.Entity<Donation>(entity =>
        {
            entity.ToTable("donations");
            entity.HasKey(e => e.DonationId);

            entity.Property(e => e.DonationId).HasColumnName("donation_id");
            entity.Property(e => e.DonorId).HasColumnName("donor_id");
            entity.Property(e => e.NgoId).HasColumnName("ngo_id");
            entity.Property(e => e.ShelterId).HasColumnName("shelter_id");
            entity.Property(e => e.DonationType).HasColumnName("donation_type");
            entity.Property(e => e.Status).HasColumnName("status");
            entity.Property(e => e.DropoffRequired).HasColumnName("dropoff_required");
            entity.Property(e => e.DropoffConfirmed).HasColumnName("dropoff_confirmed");
            entity.Property(e => e.ProofPhotoUrl).HasColumnName("proof_photo_url");
            entity.Property(e => e.Remarks).HasColumnName("remarks");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");

            entity.HasOne(e => e.Donor)
                .WithMany(e => e.Donations)
                .HasForeignKey(e => e.DonorId);

            entity.HasOne(e => e.Ngo)
                .WithMany()
                .HasForeignKey(e => e.NgoId);
        });

        modelBuilder.Entity<DonationItem>(entity =>
        {
            entity.ToTable("donation_items");
            entity.HasKey(e => e.DonationItemId);

            entity.Property(e => e.DonationItemId).HasColumnName("donation_item_id");
            entity.Property(e => e.DonationId).HasColumnName("donation_id");
            entity.Property(e => e.ItemId).HasColumnName("item_id");
            entity.Property(e => e.Quantity).HasColumnName("quantity");

            entity.HasOne(e => e.Donation)
                .WithMany(e => e.DonationItems)
                .HasForeignKey(e => e.DonationId);

            entity.HasOne(e => e.Item)
                .WithMany()
                .HasForeignKey(e => e.ItemId);
        });

        modelBuilder.Entity<Donor>(entity =>
        {
            entity.ToTable("donors");
            entity.HasKey(e => e.DonorId);

            entity.Property(e => e.DonorId).HasColumnName("donor_id");
            entity.Property(e => e.PersonId).HasColumnName("person_id");
            entity.Property(e => e.DonorType).HasColumnName("donor_type");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");

            entity.HasOne(e => e.Person)
                .WithMany()
                .HasForeignKey(e => e.PersonId);

            entity.HasIndex(e => e.PersonId).IsUnique();
        });

        modelBuilder.Entity<Payment>(entity =>
        {
            entity.ToTable("payments");
            entity.HasKey(e => e.PaymentId);

            entity.Property(e => e.PaymentId).HasColumnName("payment_id");
            entity.Property(e => e.DonationId).HasColumnName("donation_id");
            entity.Property(e => e.Amount).HasColumnName("amount").HasPrecision(12, 2);
            entity.Property(e => e.Currency).HasColumnName("currency");
            entity.Property(e => e.Method).HasColumnName("method");
            entity.Property(e => e.Provider).HasColumnName("provider");
            entity.Property(e => e.ProviderRef).HasColumnName("provider_ref");
            entity.Property(e => e.ProviderBillCode).HasColumnName("provider_bill_code");
            entity.Property(e => e.ProviderInvoiceNo).HasColumnName("provider_invoice_no");
            entity.Property(e => e.ExternalReferenceNo).HasColumnName("external_reference_no");
            entity.Property(e => e.CallbackRaw).HasColumnName("callback_raw");
            entity.Property(e => e.ReceiptToken).HasColumnName("receipt_token");
            entity.Property(e => e.ReceiptIssuedAt).HasColumnName("receipt_issued_at");
            entity.Property(e => e.PaymentStatus).HasColumnName("payment_status");
            entity.Property(e => e.PaidAt).HasColumnName("paid_at");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at");

            entity.HasOne(e => e.Donation)
                .WithOne(e => e.Payment)
                .HasForeignKey<Payment>(e => e.DonationId);
        });

        modelBuilder.Entity<NgoInventory>(e =>
        {
            e.ToTable("ngo_inventory");
            e.HasKey(x => x.InventoryId);

            e.Property(x => x.InventoryId).HasColumnName("inventory_id");
            e.Property(x => x.NgoId).HasColumnName("ngo_id");
            e.Property(x => x.ItemId).HasColumnName("item_id");
            e.Property(x => x.Quantity).HasColumnName("quantity");
            e.Property(x => x.MinimumLevel).HasColumnName("minimum_level");
            e.Property(x => x.UpdatedAt).HasColumnName("updated_at");

            e.HasOne(x => x.Ngo)
                .WithMany()
                .HasForeignKey(x => x.NgoId);

            e.HasOne(x => x.Item)
                .WithMany()
                .HasForeignKey(x => x.ItemId);

            e.HasIndex(x => new { x.NgoId, x.ItemId }).IsUnique();
        });

        modelBuilder.Entity<PriorityCategory>(e =>
        {
            e.ToTable("priority_categories");
            e.HasKey(x => x.PriorityId);

            e.Property(x => x.PriorityId).HasColumnName("priority_id");
            e.Property(x => x.PriorityName).HasColumnName("priority_name");
            e.Property(x => x.Description).HasColumnName("description");
            e.Property(x => x.Weight).HasColumnName("weight");

            e.HasIndex(x => x.PriorityName).IsUnique();
        });

        modelBuilder.Entity<ShelterRequest>(e =>
        {
            e.ToTable("shelter_requests");
            e.HasKey(x => x.RequestId);

            e.Property(x => x.RequestId).HasColumnName("request_id");
            e.Property(x => x.ShelterId).HasColumnName("shelter_id");
            e.Property(x => x.UserId).HasColumnName("user_id");
            e.Property(x => x.BabiesMale).HasColumnName("babies_male");
            e.Property(x => x.BabiesFemale).HasColumnName("babies_female");
            e.Property(x => x.KidsMale).HasColumnName("kids_male");
            e.Property(x => x.KidsFemale).HasColumnName("kids_female");
            e.Property(x => x.AdultMale).HasColumnName("adult_male");
            e.Property(x => x.AdultFemale).HasColumnName("adult_female");
            e.Property(x => x.TotalPeople).HasColumnName("total_people");
            e.Property(x => x.Status).HasColumnName("status");
            e.Property(x => x.ConfirmedUserId).HasColumnName("confirmed_user_id");
            e.Property(x => x.ProcessedByUserId).HasColumnName("processed_by_user_id");
            e.Property(x => x.CreatedAt).HasColumnName("created_at");
            e.Property(x => x.ConfirmedAt).HasColumnName("confirmed_at");
            e.Property(x => x.ArrivedAt).HasColumnName("arrived_at");

            e.HasOne(x => x.Shelter)
                .WithMany()
                .HasForeignKey(x => x.ShelterId);

            e.HasOne(x => x.User)
                .WithMany()
                .HasForeignKey(x => x.UserId);

            e.HasOne(x => x.ConfirmedByUser)
                .WithMany()
                .HasForeignKey(x => x.ConfirmedUserId);
        });

        modelBuilder.Entity<ShelterRequestDependent>(e =>
        {
            e.ToTable("shelter_request_dependents");
            e.HasKey(x => x.RequestDependentId);

            e.Property(x => x.RequestDependentId).HasColumnName("request_dependent_id");
            e.Property(x => x.RequestId).HasColumnName("request_id");
            e.Property(x => x.RelationshipId).HasColumnName("relationship_id");
            e.Property(x => x.CreatedAt).HasColumnName("created_at");

            e.HasOne(x => x.Request)
                .WithMany(x => x.Dependents)
                .HasForeignKey(x => x.RequestId)
                .OnDelete(DeleteBehavior.Cascade);

            e.HasOne(x => x.Relationship)
                .WithMany()
                .HasForeignKey(x => x.RelationshipId)
                .OnDelete(DeleteBehavior.Cascade);

            e.HasIndex(x => new { x.RequestId, x.RelationshipId }).IsUnique();
        });

        modelBuilder.Entity<DeviceToken>(e =>
        {
            e.ToTable("device_tokens");
            e.HasKey(x => x.TokenId);

            e.Property(x => x.TokenId).HasColumnName("token_id");
            e.Property(x => x.UserId).HasColumnName("user_id");
            e.Property(x => x.Token).HasColumnName("token");
            e.Property(x => x.Platform).HasColumnName("platform");
            e.Property(x => x.IsActive).HasColumnName("is_active");
            e.Property(x => x.CreatedAt).HasColumnName("created_at");
            e.Property(x => x.UpdatedAt).HasColumnName("updated_at");

            e.HasOne(x => x.User)
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            e.HasIndex(x => new { x.UserId, x.Token }).IsUnique();
        });

        modelBuilder.Entity<InventoryTransaction>(e =>
        {
            e.ToTable("inventory_transactions");
            e.HasKey(x => x.TransactionId);

            e.Property(x => x.TransactionId).HasColumnName("transaction_id");
            e.Property(x => x.OwnerType).HasColumnName("owner_type");
            e.Property(x => x.OwnerId).HasColumnName("owner_id");
            e.Property(x => x.ItemId).HasColumnName("item_id");
            e.Property(x => x.TransactionType).HasColumnName("transaction_type");
            e.Property(x => x.Quantity).HasColumnName("quantity");
            e.Property(x => x.SourceType).HasColumnName("source_type");
            e.Property(x => x.SourceId).HasColumnName("source_id");
            e.Property(x => x.Note).HasColumnName("note");
            e.Property(x => x.CreatedBy).HasColumnName("created_by");
            e.Property(x => x.CreatedAt).HasColumnName("created_at");

            e.HasOne(x => x.Item)
                .WithMany()
                .HasForeignKey(x => x.ItemId);

            e.HasOne(x => x.CreatedByUser)
                .WithMany()
                .HasForeignKey(x => x.CreatedBy);
        });

        modelBuilder.Entity<AuditLog>(e =>
        {
            e.ToTable("audit_logs");
            e.HasKey(x => x.LogId);

            e.Property(x => x.LogId).HasColumnName("log_id");
            e.Property(x => x.UserId).HasColumnName("user_id");
            e.Property(x => x.Action).HasColumnName("action");
            e.Property(x => x.Entity).HasColumnName("entity");
            e.Property(x => x.EntityId).HasColumnName("entity_id");
            e.Property(x => x.Detail).HasColumnName("detail");
            e.Property(x => x.CreatedAt).HasColumnName("created_at");

            e.HasOne(x => x.User)
                .WithMany()
                .HasForeignKey(x => x.UserId);
        });

        modelBuilder.Entity<DeliveryGroup>(entity =>
        {
            entity.ToTable("delivery_groups");

            entity.HasKey(e => e.DeliveryGroupId);

            entity.Property(e => e.DeliveryGroupId).HasColumnName("delivery_group_id");
            entity.Property(e => e.NgoId).HasColumnName("ngo_id");
            entity.Property(e => e.AssignedTo).HasColumnName("assigned_to");
            entity.Property(e => e.GroupName).HasColumnName("group_name");

            entity.Property(e => e.Status)
                .HasColumnName("status")
                .HasConversion<string>();

            entity.Property(e => e.ScheduledDate)
                .HasColumnName("scheduled_date")
                .HasConversion(
                    v => v.HasValue ? v.Value.ToDateTime(TimeOnly.MinValue) : (DateTime?)null,
                    v => v.HasValue ? DateOnly.FromDateTime(v.Value) : (DateOnly?)null
                );

            entity.Property(e => e.OriginLat).HasColumnName("origin_lat");
            entity.Property(e => e.OriginLng).HasColumnName("origin_lng");
            entity.Property(e => e.TotalDistanceKm).HasColumnName("total_distance_km");
            entity.Property(e => e.TotalEtaMinutes).HasColumnName("total_eta_minutes");
            entity.Property(e => e.GoogleMapsUrl).HasColumnName("google_maps_url");
            entity.Property(e => e.OptimizedAt).HasColumnName("optimized_at");
            entity.Property(e => e.Notes).HasColumnName("notes");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");

            entity.HasOne(e => e.Ngo)
                .WithMany()
                .HasForeignKey(e => e.NgoId);

            entity.HasOne(e => e.AssignedUser)
                .WithMany()
                .HasForeignKey(e => e.AssignedTo);
        });

        modelBuilder.Entity<DeliveryGroupDelivery>(entity =>
        {
            entity.ToTable("delivery_group_deliveries");

            entity.HasKey(e => e.DeliveryGroupDeliveryId);

            entity.Property(e => e.DeliveryGroupDeliveryId)
                .HasColumnName("delivery_group_delivery_id");

            entity.Property(e => e.DeliveryGroupId)
                .HasColumnName("delivery_group_id");

            entity.Property(e => e.DeliveryId)
                .HasColumnName("delivery_id");

            entity.Property(e => e.RequestedStopOrder)
                .HasColumnName("requested_stop_order");

            entity.Property(e => e.OptimizedStopOrder)
                .HasColumnName("optimized_stop_order");

            entity.Property(e => e.CreatedAt)
                .HasColumnName("created_at");

            entity.HasOne(e => e.DeliveryGroup)
                .WithMany(g => g.GroupDeliveries)
                .HasForeignKey(e => e.DeliveryGroupId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Delivery)
                .WithMany(d => d.DeliveryGroupDeliveries)
                .HasForeignKey(e => e.DeliveryId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(e => new { e.DeliveryGroupId, e.DeliveryId })
                .IsUnique();

            entity.HasIndex(e => e.DeliveryId)
                .IsUnique();
        });


    }
}
