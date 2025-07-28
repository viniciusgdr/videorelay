import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './index.css';
import process from 'process';

window.process = process;

const root = ReactDOM.createRoot(
  document.getElementById('root') as HTMLElement
);
root.render(
  <App />
);

