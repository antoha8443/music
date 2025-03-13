export class AudioPlayer {
    private audioElement: HTMLAudioElement | null = null;

    constructor() {
        this.audioElement = new Audio();
    }

    public stopAudio(): void {
        if (this.audioElement) {
            this.audioElement.pause();
            this.audioElement.currentTime = 0;
        }
    }

    public play(audioSource: string): void {
        if (this.audioElement) {
            this.audioElement.src = audioSource;
            this.audioElement.play().catch(error => {
                console.error('Error playing audio:', error);
            });
        }
    }

    public pauseAudio(): void {
        if (this.audioElement) {
            this.audioElement.pause();
        }
    }

    public seekTo(time: number): void {
        if (this.audioElement) {
            this.audioElement.currentTime = time;
        }
    }

    public getCurrentTime(): number {
        return this.audioElement ? this.audioElement.currentTime : 0;
    }

    public getDuration(): number {
        return this.audioElement ? this.audioElement.duration : 0;
    }

    public skipForward(seconds: number = 10): void {
        if (this.audioElement) {
            this.audioElement.currentTime = Math.min(
                this.audioElement.currentTime + seconds,
                this.audioElement.duration
            );
        }
    }

    public skipBackward(seconds: number = 10): void {
        if (this.audioElement) {
            this.audioElement.currentTime = Math.max(
                this.audioElement.currentTime - seconds,
                0
            );
        }
    }
}
