import 'dart:async';

import 'package:flutter/foundation.dart';

import 'smart_travel_agent.dart';
import 'travel_data_service.dart';

class TrackingAgent {
  static final TrackingAgent instance = TrackingAgent._();
  TrackingAgent._();

  Timer? _simulationTimer;
  final ValueNotifier<bool> isSimulating = ValueNotifier(false);
  int _currentTargetIndex = 0;

  void toggleSimulation() {
    if (isSimulating.value) {
      stopSimulation();
    } else {
      startSimulation();
    }
  }

  void startSimulation() {
    isSimulating.value = true;
    _currentTargetIndex = 0;
    
    _simulationTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _simulateMovementTick();
    });
    
    SmartTravelAgent.instance.reminders.triggerSuggestion("Passive Tracking Agent Simulation Started...");
  }

  void stopSimulation() {
    isSimulating.value = false;
    _simulationTimer?.cancel();
    SmartTravelAgent.instance.reminders.triggerSuggestion("Tracking Simulation Stopped.");
  }

  void _simulateMovementTick() {
    final travelData = TravelDataService.instance;
    final stops = travelData.itineraryStops;
    
    if (stops.isEmpty) {
      stopSimulation();
      return;
    }

    // Find the next unvisited stop
    while (_currentTargetIndex < stops.length && 
           travelData.visitedPlaceIds.contains(stops[_currentTargetIndex].place)) {
      _currentTargetIndex++;
    }

    if (_currentTargetIndex >= stops.length) {
      stopSimulation();
      return;
    }

    final targetStop = stops[_currentTargetIndex];
    
    // Push the event through the Sequence Diagram flow: Tracking -> Trip -> Reminder
    SmartTravelAgent.instance.trip.onPlaceVisited(targetStop.place);
  }
}
