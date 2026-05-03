import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';

/**
 * HeroCard
 * Top card showing the app title and Open/Reset buttons.
 *
 * Props:
 *  onOpen  - opens the camera
 *  onReset - closes and resets the camera
 */
export default function HeroCard({ onOpen, onReset }) {
  return (
    <View style={styles.card}>
      <Text style={styles.heading}>
        Rear obstacle distance detector
      </Text>
      <Text style={styles.subheading}>
        Real-time distance estimation using camera + pinhole formula
      </Text>
      <View style={styles.ctaRow}>
        <TouchableOpacity style={styles.primaryButton} onPress={onOpen}>
          <Text style={styles.primaryButtonText}>Open camera</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.secondaryButton} onPress={onReset}>
          <Text style={styles.secondaryButtonText}>Reset</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: 'rgba(10, 20, 35, 0.88)',
    borderColor: 'rgba(255, 255, 255, 0.08)',
    borderWidth: 1,
    borderRadius: 28,
    padding: 22,
    gap: 10,
  },
  heading: {
    color: '#ffffff',
    fontSize: 26,
    fontWeight: '800',
    lineHeight: 32,
  },
  subheading: {
    color: 'rgba(234, 241, 255, 0.7)',
    fontSize: 14,
    lineHeight: 20,
  },
  ctaRow: {
    flexDirection: 'row',
    gap: 12,
    marginTop: 8,
    flexWrap: 'wrap',
  },
  primaryButton: {
    backgroundColor: '#5de1ff',
    paddingVertical: 14,
    paddingHorizontal: 22,
    borderRadius: 18,
    minWidth: 140,
    alignItems: 'center',
  },
  primaryButtonText: {
    color: '#04111c',
    fontSize: 15,
    fontWeight: '800',
  },
  secondaryButton: {
    backgroundColor: 'rgba(255, 255, 255, 0.06)',
    borderColor: 'rgba(255, 255, 255, 0.08)',
    borderWidth: 1,
    paddingVertical: 14,
    paddingHorizontal: 22,
    borderRadius: 18,
    minWidth: 100,
    alignItems: 'center',
  },
  secondaryButtonText: {
    color: '#eff7ff',
    fontSize: 15,
    fontWeight: '700',
  },
});