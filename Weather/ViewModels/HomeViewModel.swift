//
//  CityViewModel.swift
//  Weather
//
//  Created by Odet Alexandre on 27/09/2017.
//  Copyright © 2017 Odet Alexandre. All rights reserved.
//

import Foundation
import CoreLocation

import RxSwift
import RxCocoa

final class HomeViewModel: NSObject {
  
  var restApiWeather = OpenWeatherApiCommunication()
  
  var cityName = Variable<String>("")
  var countryName = Variable<String>("")
  var items = Variable<[APIResponseWeather]>([])

  
  var isValid : Observable<Bool>{
    return Observable.combineLatest(self.cityName.asObservable(), self.countryName.asObservable()) { !$0.isEmpty && !$1.isEmpty }
  }
    
  var requestHasFailed = BehaviorSubject<Bool>(value: false)
  
  private var disposeBag = DisposeBag()
  private var locationManager = CLLocationManager()
  
  func cancelRequest() {
    restApiWeather.cancelRequest()
  }

  
  func fetchWeatherFromApi(with city: String, in country: String) {
    if Utils.network.isNetworkAvailable {
      restApiWeather.getWeather(from: city, in: country).subscribe(
        onNext: { [weak self] data in
          guard let strongSelf = self else { return }
          if let index = strongSelf.items.value.index(where: { $0.name == data.name }) {
            strongSelf.items.value[index] = data
          } else {
            strongSelf.items.value.append(data)
          }
        },
        onError: { [weak self] error in
          guard let strongSelf = self else { return }
          strongSelf.requestHasFailed.onError(error)
      }).disposed(by: disposeBag)
    }
  }
  
  func fetchWeatherFromApi(with coordinates: [Double]) {
    if Utils.network.isNetworkAvailable {
      restApiWeather.getWeather(from: coordinates).subscribe(
        onNext: { [weak self] data in
          guard let strongSelf = self else { return }
          if let index = strongSelf.items.value.index(where: { $0.name == data.name }) {
            strongSelf.items.value[index] = data
          } else {
            strongSelf.items.value.append(data)
          }
        },
        onError:{ [weak self] error in
          guard let strongSelf = self else { return }
          strongSelf.requestHasFailed.onError(error)
      }).disposed(by: disposeBag)
    }
  }
  
  func viewDidLoad() {
    if let cities = CityManager.fetchCitiesFromFile() {
      for city in cities.cities {
        fetchWeatherFromApi(with: city.name, in: city.country)
      }
    }
  }
  
  func didTapSaveButton() {
    let cities = Cities()
    for item in items.value {
      let city = City()
      city.latitude = item.coordinates.latitude
      city.longitude = item.coordinates.longitude
      city.name = item.name
      city.country = item.systemInfos.country
      cities.cities.append(city)
    }
    CityManager.saveCitiesToFile(data: cities)
    cities.cities.removeAll()
  }
}

extension HomeViewModel: CLLocationManagerDelegate {
  func getUserLocation() {
    requestLocationAccess()
    if CLLocationManager.locationServicesEnabled() {
      locationManager.startUpdatingLocation()
      locationManager.desiredAccuracy = kCLLocationAccuracyBest
      locationManager.delegate = self
    }
  }
  
  private func requestLocationAccess() {
    let status = CLLocationManager.authorizationStatus()
    
    switch status {
    case .authorizedAlways, .authorizedWhenInUse:
      return
    case .denied, .restricted:
      return
    default:
      locationManager.requestWhenInUseAuthorization()
    }
  }
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    if let lastUserLocation = locations.last {
      let lat = lastUserLocation.coordinate.latitude
      let long = lastUserLocation.coordinate.longitude
      
      let coordinates = [lat, long]
      fetchWeatherFromApi(with: coordinates)
    }
    manager.stopUpdatingLocation()
  }
}
