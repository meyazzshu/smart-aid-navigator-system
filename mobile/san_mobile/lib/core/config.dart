class AppConfig {
  static const String apiBaseUrl = 'http://10.0.2.2/san_api/public';
  // static const String apiBaseUrl = 'http://10.38.63.202/san_api/public';
  // static const String apiBaseUrl = 'http://10.255.68.202/san_api/public';

  // Google Maps / Directions API key
  static const String mapsApiKey = 'AIzaSyCywy53o-vPO63ru6PGhojoaVbxNggQ-nU';

  // Supabase project settings
  static const String supabaseUrl = 'https://dhqafwdpxochdjibskki.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_6_8wmCQ7MQnoCLryc71vKA_o3TNZJRE';
  
  // static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRocWFmd2RweG9jaGRqaWJza2tpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5MTA2MTcsImV4cCI6MjA5MjQ4NjYxN30.d3WfxqftKPiEJn1wszCJJtBrP24VaFczUuLzzaTNE5M';

  // Supabase Storage bucket for drop-off proof photos
  static const String dropoffProofsBucket = 'images';
}
