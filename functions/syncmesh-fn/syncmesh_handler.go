package function

import (
	"bytes"
	"encoding/json"
	"log"
	"net/http"
)

// handleSyncMeshRequest by instantiating one of the request types
func handleSyncMeshRequest(request SyncMeshRequest, ownResponse string) *bytes.Buffer {
	b := new(bytes.Buffer)
	switch request.Type {
	case "aggregate":
		startAggregating(request, ownResponse, b)
	case "collect":
		startCollecting(request, ownResponse, b)
	case "function":
		startFunction(request, ownResponse, b)
	}
	return b
}

// startCollecting the data from external nodes
func startCollecting(request SyncMeshRequest, ownResponse string, b *bytes.Buffer) {
	combinedResponse := ownResponse
	// start iterating through all external nodes
	for _, address := range request.ExternalNodes {
		err, body := makeExternalRequest(request, address)
		if err != nil {
			log.Println(err)
			continue
		}
		// convert response to response struct
		out := GraphQLResponse{}
		err = json.Unmarshal(body, &out)
		// convert the combined response to response struct
		combined := GraphQLResponse{}
		err = json.Unmarshal([]byte(combinedResponse), &combined)
		// merge combined and external node responses
		combined.Data.Sensors = append(combined.Data.Sensors, out.Data.Sensors...)
		outputJSON, _ := json.Marshal(combined)
		combinedResponse = string(outputJSON)
		if err != nil {
			log.Println(err)
			continue
		}
	}
	err := json.NewEncoder(b).Encode(json.RawMessage(combinedResponse))
	if err != nil {
		log.Fatal(err)
	}
}

// startAggregating the data from external nodes
func startAggregating(request SyncMeshRequest, ownResponse string, b *bytes.Buffer) {
	var averagesList []AveragesResponse
	own := AveragesResponse{}
	err := json.Unmarshal([]byte(ownResponse), &own)
	if err != nil {
		return
	}
	averagesList = append(averagesList, own)
	// start iterating through all external nodes
	for _, address := range request.ExternalNodes {
		err, body := makeExternalRequest(request, address)
		if err != nil {
			log.Println(err)
			continue
		}
		// convert response to response struct
		out := AveragesResponse{}
		err = json.Unmarshal(body, &out)
		if err != nil {
			log.Println(err)
			continue
		}
		// add external node averages to averages list
		averagesList = append(averagesList, out)
	}
	finalAverages := calculateAverages(averagesList)
	outputJSON, _ := json.Marshal(finalAverages)
	err = json.NewEncoder(b).Encode(json.RawMessage(string(outputJSON)))
	if err != nil {
		log.Fatal(err)
	}
}

// start request to local faas function
func startFunction(request SyncMeshRequest, ownResponse string, b *bytes.Buffer) {

	// make a POST request to faas function
	req, err := http.NewRequest("POST", "http://gateway:8080/function/test", bytes.NewBuffer([]byte(ownResponse)))
	if err != nil {
		return
	}
	// req.Header.Set("Content-Type", "application/json")
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return
	}
	// read the response
	body, err := unzipResponse(resp)
	if err != nil {
		return
	}
	err = resp.Body.Close()
	if err != nil {
		return
	}

	// convert response to response struct
	// out := AveragesResponse{}
	// err = json.Unmarshal(body, &out)
	// if err != nil {
	// 	log.Println(err)
	// 	return
	// }

	// outputJSON, _ := json.Marshal(body)
	err = json.NewEncoder(b).Encode(json.RawMessage(string(body)))
	if err != nil {
		log.Fatal(err)
	}
}

// makeExternalRequest to one of the syncmesh nodes
func makeExternalRequest(request SyncMeshRequest, url string) (error, []byte) {
	// prepare SyncMesh Request body for the external request
	requestStruct := &SyncMeshRequest{
		Query:      request.Query,
		Database:   request.Database,
		Collection: request.Collection,
		Type:       request.Type,
	}
	jsonBody, err := json.Marshal(requestStruct)
	if err != nil {
		return err, nil
	}
	// make a POST request to external nodes, fetching the data
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonBody))
	if err != nil {
		return err, nil
	}
	req.Header.Set("Content-Type", "application/json")
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return err, nil
	}
	// read the response
	body, err := unzipResponse(resp)
	if err != nil {
		return err, nil
	}
	err = resp.Body.Close()
	if err != nil {
		return err, nil
	}
	return nil, body
}

// calculateAverages of sensor data for aggregation
func calculateAverages(averagesList []AveragesResponse) AveragesResponse {
	final := AveragesResponse{AveragePressure: 0, AverageTemperature: 0, AverageHumidity: 0}
	size := float64(len(averagesList))
	if size == 0 {
		return final
	}
	// sum all values
	for _, item := range averagesList {
		final.AverageHumidity += item.AverageHumidity
		final.AverageTemperature += item.AverageTemperature
		final.AveragePressure += item.AveragePressure
	}
	// calculate the averages
	final.AverageHumidity /= size
	final.AverageTemperature /= size
	final.AveragePressure /= size
	return final
}
