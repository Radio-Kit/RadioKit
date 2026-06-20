import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import tailwindcss from '@tailwindcss/vite';
import starlightSidebarTopics from 'starlight-sidebar-topics';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  site: 'https://radiokit.app',
  vite: {
    plugins: [tailwindcss()],
    resolve: {
      alias: {
        '@themes': path.resolve(__dirname, '../themes'),
      },
    },
  },
  integrations: [
    starlight({
      title: 'RADIO_KIT',
      logo: {
        src: './public/logo.svg',
        alt: 'RADIO_KIT Logo',
      },
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          href: 'https://github.com/rambros3d/RadioKit',
        },
      ],
      plugins: [
        starlightSidebarTopics([
          {
            label: 'App',
            link: '/app/overview',
            items: [
              { label: 'Overview', link: '/app/overview' },
              { label: 'Getting Started', link: '/app/getting-started' },
              { label: 'Installation', link: '/app/installation' },
              { label: 'Quick Start', link: '/app/quick-start' },
              { label: 'Features', link: '/app/features' },
              { label: 'Designer Manual', link: '/app/designer' },
            ],
          },
          {
            label: 'Arduino',
            link: '/arduino/overview',
            items: [
              { label: 'Overview', link: '/arduino/overview' },
              { label: 'Getting Started', link: '/arduino/setup' },
              { label: 'Widgets Reference', link: '/arduino/widgets' },
              { label: 'UI Layout', link: '/arduino/ui-layout' },
              { label: 'UI Skins', link: '/arduino/ui-skin' },
              { label: 'Transports', link: '/arduino/transports' },
              { label: 'Protocol', link: '/arduino/protocol' },
            ],
          },
          {
            label: 'Flutter Widgets',
            link: '/widgets/overview',
            items: [
              { label: 'Overview', link: '/widgets/overview' },
              { label: 'RKButton', link: '/widgets/rk-button' },
              { label: 'RKSlider', link: '/widgets/rk-slider' },
              { label: 'RKKnob', link: '/widgets/rk-knob' },
              { label: 'RKJoystick', link: '/widgets/rk-joystick' },
              { label: 'RKLed', link: '/widgets/rk-led' },
              { label: 'RKDisplay', link: '/widgets/rk-display' },
              { label: 'RKSerialMonitor', link: '/widgets/rk-serial-monitor' },
              { label: 'RKMultiButton', link: '/widgets/rk-multi-button' },
              { label: 'RKMultiSelect', link: '/widgets/rk-multi-select' },
              { label: 'RKRockerSwitch', link: '/widgets/rk-rocker-switch' },
              { label: 'RKSlideSwitch', link: '/widgets/rk-slide-switch' },
            ],
          },
        ]),
      ],
      customCss: [
        './src/styles/custom.css',
      ],
      components: {
        Header: './src/components/overrides/Header.astro',
      },
    }),
  ],
});
