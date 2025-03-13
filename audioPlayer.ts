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
}
