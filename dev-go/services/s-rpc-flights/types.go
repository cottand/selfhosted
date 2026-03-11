package module

type GetAirportResponse struct {
	Data struct {
		Id         string `json:"id"`
		Type       string `json:"type"`
		Attributes struct {
			Name      string `json:"name"`
			Code      string `json:"code"`
			Type      string `json:"type"`
			Latitude  string `json:"latitude"`
			Longitude string `json:"longitude"`
			Elevation int    `json:"elevation"`
			GpsCode   string `json:"gps_code"`
			IcaoCode  string `json:"icao_code"`
			IataCode  string `json:"iata_code"`
			LocalCode string `json:"local_code"`
		} `json:"attributes"`
		Relationships struct {
			Country struct {
				Data struct {
					Type string `json:"type"`
					Id   string `json:"id"`
				} `json:"data"`
			} `json:"country"`
			Region struct {
				Data struct {
					Type string `json:"type"`
					Id   string `json:"id"`
				} `json:"data"`
			} `json:"region"`
		} `json:"relationships"`
		Links struct {
			Self struct {
				Href        string `json:"href"`
				Rel         string `json:"rel"`
				Describedby string `json:"describedby"`
				Title       string `json:"title"`
				Type        string `json:"type"`
				Hreflang    string `json:"hreflang"`
				Meta        struct {
				} `json:"meta"`
			} `json:"self"`
		} `json:"links"`
	} `json:"data"`
}
