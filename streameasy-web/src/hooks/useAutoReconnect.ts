import { useEffect, useRef, useCallback } from 'react';

interface AutoReconnectConfig {
  isConnected: boolean;
  connectionState: string;
  error: string | null;
  onReconnect: () => void;
  maxAttempts?: number;
  initialDelay?: number;
  maxDelay?: number;
  enabled?: boolean;
}

export const useAutoReconnect = ({
  isConnected,
  connectionState,
  error,
  onReconnect,
  maxAttempts = 5,
  initialDelay = 2000,
  maxDelay = 30000,
  enabled = true
}: AutoReconnectConfig) => {
  const attemptsRef = useRef(0);
  const timeoutRef = useRef<NodeJS.Timeout | null>(null);
  const lastConnectionStateRef = useRef(connectionState);

  const calculateDelay = useCallback((attempt: number) => {
    return Math.min(initialDelay * Math.pow(2, attempt), maxDelay);
  }, [initialDelay, maxDelay]);

  const attemptReconnect = useCallback(() => {
    if (!enabled || attemptsRef.current >= maxAttempts) {
      console.log('Auto-reconnect disabled or max attempts reached');
      return;
    }

    const delay = calculateDelay(attemptsRef.current);
    console.log(`Attempting reconnect ${attemptsRef.current + 1}/${maxAttempts} in ${delay}ms`);

    timeoutRef.current = setTimeout(() => {
      attemptsRef.current += 1;
      onReconnect();
    }, delay);
  }, [enabled, maxAttempts, calculateDelay, onReconnect]);

  useEffect(() => {
    // Reset counter when successfully connected
    if (isConnected && connectionState === 'connected') {
      attemptsRef.current = 0;
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
        timeoutRef.current = null;
      }
    }
  }, [isConnected, connectionState]);

  useEffect(() => {
    const shouldReconnect = 
      enabled &&
      !isConnected &&
      (connectionState === 'disconnected' || connectionState === 'failed' || connectionState === 'closed') &&
      lastConnectionStateRef.current !== connectionState &&
      attemptsRef.current < maxAttempts;

    if (shouldReconnect) {
      console.log('Connection lost, scheduling reconnect...');
      attemptReconnect();
    }

    lastConnectionStateRef.current = connectionState;
  }, [connectionState, isConnected, enabled, maxAttempts, attemptReconnect]);

  useEffect(() => {
    // Cleanup timeout on unmount
    return () => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
    };
  }, []);

  return {
    reconnectAttempts: attemptsRef.current,
    isReconnecting: timeoutRef.current !== null
  };
};
