package overcut.rest.dtos;

public class PilotSuggestionDto {
    public Long driverId;
    public String driverName;

    public PilotSuggestionDto() {}

    public PilotSuggestionDto(Long driverId, String driverName) {
        this.driverId = driverId;
        this.driverName = driverName;
    }
   

    public Long getDriverId() { return driverId; }
    public void setDriverId(Long driverId) { this.driverId = driverId; }

    public String getDriverName() { return driverName; }
    public void setDriverName(String driverName) { this.driverName = driverName; }
}
