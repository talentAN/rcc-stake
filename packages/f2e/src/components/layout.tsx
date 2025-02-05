import { ReactNode } from 'react';
import Header from './header';
import styles from '../styles/Home.module.css';

export default function Layout({ children }: { children: ReactNode }) {
  return (
    <div className={styles.container}>
      <Header></Header>
      <main className={styles.main}>{children}</main>
    </div>
  );
}
