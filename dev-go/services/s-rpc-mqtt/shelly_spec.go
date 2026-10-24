package module

type ShellyCronSpec struct {
	Enable   bool             `json:"enable"`
	Timespec string           `json:"timespec"`
	Calls    []ShellyCallSpec `json:"calls"`
}

type ShellyCallSpec struct {
	Method string            `json:"method"`
	Params ShellyLightParams `json:"params"`
}

type ShellyLightParams struct {
	Id         int   `json:"id"`
	On         *bool `json:"on,omitempty"`
	Brightness *int  `json:"brightness,omitempty"`
}

var aquariumSchedule = []ShellyCronSpec{
	{
		Enable:   true,
		Timespec: "30 7 * * *",
		Calls: []ShellyCallSpec{
			{Method: "light.set", Params: ShellyLightParams{Id: 0, On: new(true), Brightness: new(15)}},
		},
	},
	{
		Enable:   true,
		Timespec: "30 8 * * *",
		Calls: []ShellyCallSpec{
			{Method: "light.set", Params: ShellyLightParams{Id: 0, Brightness: new(60)}},
		},
	},
	{
		Enable:   true,
		Timespec: "0 12 * * *",
		Calls: []ShellyCallSpec{
			{Method: "light.set", Params: ShellyLightParams{Id: 0, Brightness: new(5)}},
		},
	},
	{
		Enable:   true,
		Timespec: "0 16 * * *",
		Calls: []ShellyCallSpec{
			{Method: "light.set", Params: ShellyLightParams{Id: 0, Brightness: new(59)}},
		},
	},
	{
		Enable:   true,
		Timespec: "0 17 * * *",
		Calls: []ShellyCallSpec{
			{Method: "light.set", Params: ShellyLightParams{Id: 0, Brightness: new(25)}},
		},
	},
	{
		Enable:   true,
		Timespec: "0 18 * * *",
		Calls: []ShellyCallSpec{
			{Method: "light.set", Params: ShellyLightParams{Id: 0, Brightness: new(10)}},
		},
	},
	{
		Enable:   true,
		Timespec: "0 20 * * *",
		Calls: []ShellyCallSpec{
			{Method: "light.set", Params: ShellyLightParams{Id: 0, Brightness: new(3)}},
		},
	},
	{
		Enable:   true,
		Timespec: "0 22 * * *",
		Calls: []ShellyCallSpec{
			{Method: "light.set", Params: ShellyLightParams{Id: 0, On: new(false)}},
		},
	},
}
