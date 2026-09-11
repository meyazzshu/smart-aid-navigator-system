using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using SmartAidNavigator.Web.ViewModels.Reports;

namespace SmartAidNavigator.Web.Services;

public class ReportPdfService
{
    public byte[] GenerateReportPdf(ReportVm vm)
    {
        return Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Margin(30);
                page.Size(PageSizes.A4.Landscape());

                page.Header().Column(col =>
                {
                    col.Item().Text("Smart Aid Navigator")
                        .FontSize(18)
                        .Bold()
                        .FontColor(Colors.Blue.Darken3);

                    col.Item().Text(vm.Title)
                        .FontSize(15)
                        .Bold();

                    col.Item().Text(vm.Subtitle)
                        .FontSize(9)
                        .FontColor(Colors.Grey.Darken1);

                    col.Item().Text($"Generated: {vm.GeneratedAt:dd MMM yyyy HH:mm}")
                        .FontSize(8)
                        .FontColor(Colors.Grey.Darken2);

                    col.Item().PaddingBottom(10).LineHorizontal(1);
                });

                page.Content().Column(col =>
                {
                    if (vm.Stats.Any())
                    {
                        col.Item().PaddingBottom(12).Table(table =>
                        {
                            table.ColumnsDefinition(columns =>
                            {
                                foreach (var _ in vm.Stats)
                                {
                                    columns.RelativeColumn();
                                }
                            });

                            foreach (var stat in vm.Stats)
                            {
                                table.Cell()
                                    .Border(1)
                                    .BorderColor(Colors.Grey.Lighten2)
                                    .Padding(8)
                                    .Column(c =>
                                    {
                                        c.Item().Text(stat.Label).FontSize(8).FontColor(Colors.Grey.Darken1);
                                        c.Item().Text(stat.Value).FontSize(14).Bold();
                                    });
                            }
                        });
                    }

                    col.Item().Table(table =>
                    {
                        table.ColumnsDefinition(columns =>
                        {
                            foreach (var _ in vm.Columns)
                            {
                                columns.RelativeColumn();
                            }
                        });

                        foreach (var header in vm.Columns)
                        {
                            table.Cell()
                                .Background(Colors.Blue.Darken3)
                                .Padding(5)
                                .Text(header)
                                .FontSize(8)
                                .Bold()
                                .FontColor(Colors.White);
                        }

                        foreach (var row in vm.Rows)
                        {
                            foreach (var cell in row)
                            {
                                table.Cell()
                                    .BorderBottom(1)
                                    .BorderColor(Colors.Grey.Lighten2)
                                    .Padding(5)
                                    .Text(cell ?? "-")
                                    .FontSize(8);
                            }
                        }
                    });
                });

                page.Footer()
                    .AlignCenter()
                    .Text(x =>
                    {
                        x.Span("Page ");
                        x.CurrentPageNumber();
                        x.Span(" of ");
                        x.TotalPages();
                    });
            });
        }).GeneratePdf();
    }
}